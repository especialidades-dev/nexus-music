import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'components/search_item.dart';
import '/ui/screens/Settings/settings_screen_controller.dart';
import '/ui/navigator.dart';
import 'search_screen_controller.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final FocusNode _focusNode;
  late final TextEditingController _controller;
  late final SearchScreenController _searchCtrl;

  @override
  void initState() {
    super.initState();
    _searchCtrl = Get.put(SearchScreenController());
    _focusNode = FocusNode();
    _controller = _searchCtrl.textInputController;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsCtrl = Get.find<SettingsScreenController>();
    final topPadding = context.isLandscape ? 50.0 : 80.0;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Row(
        children: [
          settingsCtrl.isBottomNavBarEnabled.isFalse
              ? Container(
                  width: 60,
                  color:
                      Theme.of(context).navigationRailTheme.backgroundColor,
                  child: Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.only(top: topPadding),
                        child: IconButton(
                          icon: Icon(
                            Icons.arrow_back_ios_new,
                            color: Theme.of(context)
                                .textTheme
                                .titleMedium!
                                .color,
                          ),
                          onPressed: () {
                            Get.nestedKey(ScreenNavigationSetup.id)!
                                .currentState!
                                .pop();
                          },
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox(width: 15),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: topPadding, left: 5),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "search".tr,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    textCapitalization: TextCapitalization.none,
                    textInputAction: TextInputAction.search,
                    onChanged: _searchCtrl.onChanged,
                    onSubmitted: (val) {
                      if (val.contains("https://")) {
                        _searchCtrl.filterLinks(Uri.parse(val));
                        _searchCtrl.reset();
                        return;
                      }
                      Get.toNamed(ScreenNavigationSetup.searchResultScreen,
                          id: ScreenNavigationSetup.id, arguments: val);
                      _searchCtrl.addToHistryQueryList(val);
                    },
                    cursorColor: Theme.of(context).textTheme.bodySmall!.color,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.only(left: 5),
                      focusColor: Colors.white,
                      hintText: "searchDes".tr,
                      suffix: IconButton(
                        onPressed: _searchCtrl.reset,
                        icon: const Icon(Icons.close),
                        splashRadius: 16,
                        iconSize: 19,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Obx(() {
                      final isEmpty = _searchCtrl
                              .suggestionList.isEmpty ||
                          _searchCtrl.textInputController.text ==
                              "";
                      final list = isEmpty
                          ? _searchCtrl.historyQuerylist.toList()
                          : _searchCtrl.suggestionList.toList();
                      return ListView(
                        padding: const EdgeInsets.only(top: 5, bottom: 400),
                        physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics()),
                        children: _searchCtrl.urlPasted.isTrue
                            ? [
                                InkWell(
                                  onTap: () {
                                    _searchCtrl.filterLinks(Uri.parse(
                                        _searchCtrl.textInputController.text));
                                    _searchCtrl.reset();
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10.0),
                                    child: SizedBox(
                                      width: double.maxFinite,
                                      height: 60,
                                      child: Center(
                                          child: Text(
                                        "urlSearchDes".tr,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium,
                                      )),
                                    ),
                                  ),
                                )
                              ]
                            : list
                                .map((item) => SearchItem(
                                    queryString: item,
                                    isHistoryString: isEmpty))
                                .toList(),
                      );
                    }),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
