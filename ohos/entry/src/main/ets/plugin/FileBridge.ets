import picker from '@ohos.file.picker';
import fs from '@ohos.file.fs';
import fileShare from '@ohos.fileshare';
import fileUri from '@ohos.file.fileuri';
import common from '@ohos.app.ability.common';
import { MethodChannel, MethodCall, MethodResult, MethodCallHandler } from '@ohos/flutter_ohos';

interface FolderPickResult {
  uri: string;
  name: string;
  path: string;
  persisted: boolean;
}

/**
 * Native folder picker + file import/export for the download location.
 *
 * `file_picker` and `permission_handler` have no OHOS implementation, so the
 * Dart side talks to this bridge instead. It uses the system
 * `DocumentViewPicker` in FOLDER mode (no permission needed) and copies
 * downloaded songs from the app sandbox into the folder the user picked.
 */
class FileBridge {
  private context: common.Context | null = null;

  setContext(context: common.Context): void {
    this.context = context;
  }

  private buildPolicy(uri: string): fileShare.PolicyInfo {
    const policy: fileShare.PolicyInfo = {
      uri: uri,
      operationMode: fileShare.OperationMode.READ_MODE | fileShare.OperationMode.WRITE_MODE,
    };
    return policy;
  }

  /** Best-effort: keep folder access across app restarts. */
  private async tryPersist(uri: string): Promise<boolean> {
    return false;
  }

  async pickFolder(): Promise<FolderPickResult | null> {
    if (!this.context) {
      console.error('NexusMusic pickFolder: no context');
      return null;
    }
    try {
      const viewPicker = new picker.DocumentViewPicker(this.context as common.Context);
      const options = new picker.DocumentSelectOptions();
      options.selectMode = picker.DocumentSelectMode.FOLDER;
      options.maxSelectNumber = 1;
      const uris: string[] = await viewPicker.select(options);
      if (uris === undefined || uris === null || uris.length === 0) {
        return null;
      }
      const uri = uris[0];
      const persisted = await this.tryPersist(uri);
      let name = '';
      let path = '';
      try {
        const fu = new fileUri.FileUri(uri);
        name = fu.name;
        path = fu.path;
      } catch (e) {
        console.error(`NexusMusic pickFolder fileUri error: ${JSON.stringify(e)}`);
      }
      const res: FolderPickResult = {
        uri: uri,
        name: name,
        path: path,
        persisted: persisted,
      };
      console.info(`NexusMusic pickFolder: ${uri} name=${name} persisted=${persisted}`);
      return res;
    } catch (e) {
      console.error(`NexusMusic pickFolder error: ${JSON.stringify(e)}`);
      return null;
    }
  }

  /** Re-activate a persisted grant (if any) and check the folder is reachable. */
  async ensureAccess(uri: string): Promise<boolean> {
    if (!uri) {
      return false;
    }
    try {
      await fileShare.activatePermission([this.buildPolicy(uri)]);
    } catch (e) {
      // Ignore: restricted paths may throw even if session access exists.
    }
    try {
      return fs.accessSync(uri);
    } catch (e) {
      return false;
    }
  }

  /** Copy a sandbox file into the picked folder; returns the destination URI. */
  async importFile(folderUri: string, fileName: string, srcPath: string): Promise<string> {
    const base = folderUri.endsWith('/') ? folderUri.substring(0, folderUri.length - 1) : folderUri;
    const destUri = `${base}/${fileName}`;
    let file: fs.File | null = null;
    try {
      console.info(`NexusMusic importFile start: folderUri=${folderUri} fileName=${fileName} srcPath=${srcPath}`);
      try {
        const srcStat = await fs.stat(srcPath);
        console.info(`NexusMusic importFile srcStat ok: size=${srcStat.size}`);
      } catch (se) {
        console.error(`NexusMusic importFile srcStat failed: ${JSON.stringify(se)}`);
      }
      file = fs.openSync(destUri, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      fs.copyFileSync(srcPath, file.fd);
      console.info(`NexusMusic importFile ok: ${destUri}`);
      return destUri;
    } catch (e) {
      console.error(`NexusMusic importFile error: ${JSON.stringify(e)}`);
      throw new Error(String(e));
    } finally {
      if (file !== null) {
        try {
          fs.closeSync(file);
        } catch (e) {
          console.error(`NexusMusic importFile close error: ${JSON.stringify(e)}`);
        }
      }
    }
  }

  fileExists(uri: string): boolean {
    if (!uri) {
      return false;
    }
    try {
      return fs.accessSync(uri);
    } catch (e) {
      return false;
    }
  }

  removeFile(uri: string): boolean {
    if (!uri) {
      return false;
    }
    try {
      fs.unlinkSync(uri);
      return true;
    } catch (e) {
      console.error(`NexusMusic removeFile error: ${JSON.stringify(e)}`);
      return false;
    }
  }
}

class FileServiceHandler implements MethodCallHandler {
  private fileBridge: FileBridge;

  constructor(fileBridge: FileBridge) {
    this.fileBridge = fileBridge;
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    switch (call.method) {
      case 'pickFolder':
        this.fileBridge.pickFolder().then((r) => {
          if (r === null) {
            result.success(null);
            return;
          }
          const map: Map<string, Object> = new Map();
          map.set('uri', r.uri);
          map.set('name', r.name);
          map.set('path', r.path);
          map.set('persisted', r.persisted);
          result.success(map);
        }).catch((e: Error) => {
          result.error('PICK_FOLDER_ERROR', String(e), null);
        });
        break;

      case 'ensureAccess': {
        const uri = call.argument('uri') as string;
        this.fileBridge.ensureAccess(uri).then((ok) => {
          result.success(ok);
        }).catch((e: Error) => {
          result.error('ENSURE_ACCESS_ERROR', String(e), null);
        });
        break;
      }

      case 'importFile': {
        const folderUri = call.argument('folderUri') as string;
        const fileName = call.argument('fileName') as string;
        const srcPath = call.argument('srcPath') as string;
        if (!folderUri || !fileName || !srcPath) {
          result.error('INVALID_ARGS', 'folderUri, fileName and srcPath are required', null);
          return;
        }
        this.fileBridge.importFile(folderUri, fileName, srcPath).then((dest) => {
          result.success(dest);
        }).catch((e: Error) => {
          result.error('IMPORT_FILE_ERROR', String(e), null);
        });
        break;
      }

      case 'fileExists': {
        const uri = call.argument('uri') as string;
        result.success(this.fileBridge.fileExists(uri));
        break;
      }

      case 'removeFile': {
        const uri = call.argument('uri') as string;
        result.success(this.fileBridge.removeFile(uri));
        break;
      }

      default:
        result.notImplemented();
    }
  }
}

export { FileBridge, FileServiceHandler };
