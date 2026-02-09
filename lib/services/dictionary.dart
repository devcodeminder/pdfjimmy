import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:translator/translator.dart';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class DictionaryController extends GetxController {
  var word = ''.obs;
  var englishMeaning = ''.obs;
  var tamilMeaning = ''.obs;
  var isLoading = false.obs;
  var historyList = <String>[].obs;

  final translator = GoogleTranslator();
  final storage = GetStorage();

  @override
  void onInit() {
    super.onInit();
    loadHistory();
  }

  void loadHistory() {
    final saved = storage.read<List>('history') ?? [];
    historyList.assignAll(saved.cast<String>());
  }

  void saveToHistory(String word) {
    if (!historyList.contains(word)) {
      historyList.insert(0, word);
      if (historyList.length > 20) historyList.removeLast();
      storage.write('history', historyList);
    }
  }

  void clearHistory() {
    historyList.clear();
    storage.remove('history');
    Get.snackbar(
      "Cleared",
      "History removed",
      backgroundColor: Colors.red.shade100,
    );
  }

  Future<void> search(String input) async {
    if (input.trim().isEmpty) return;
    word.value = input.trim();
    englishMeaning.value = '';
    tamilMeaning.value = '';
    isLoading.value = true;

    try {
      bool isTamil = RegExp(r'^[\u0B80-\u0BFF]+$').hasMatch(word.value);

      if (isTamil) {
        final url = Uri.parse(
          "https://abutech.pythonanywhere.com/dic/${Uri.encodeComponent(word.value)}",
        );
        final response = await http.get(url);
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data["result"] != null && data["result"].isNotEmpty) {
            final eng = data["result"][0][1].toString().trim();
            englishMeaning.value = eng;
            await translateToTamil(eng);
          } else {
            englishMeaning.value = "No meaning found.";
            tamilMeaning.value = "";
          }
        }
      } else {
        final url = Uri.parse(
          "https://api.dictionaryapi.dev/api/v2/entries/en/${Uri.encodeComponent(word.value)}",
        );
        final response = await http.get(url);
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final definition =
              data[0]['meanings'][0]['definitions'][0]['definition'];
          englishMeaning.value = definition;
          await translateToTamil(definition);
        } else {
          englishMeaning.value = "No meaning found.";
        }
      }

      saveToHistory(word.value);
    } catch (e) {
      englishMeaning.value = "Error: $e";
    }

    isLoading.value = false;
  }

  Future<void> translateToTamil(String text) async {
    try {
      final result = await translator.translate(text, from: 'en', to: 'ta');
      tamilMeaning.value = result.text;
    } catch (e) {
      tamilMeaning.value = "Translation failed: $e";
    }
  }
}

class DictionaryScreen extends StatefulWidget {
  const DictionaryScreen({Key? key}) : super(key: key);

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {
  final TextEditingController inputController = TextEditingController();
  late final DictionaryController controller;

  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<DictionaryController>()) {
      controller = Get.put(DictionaryController());
    } else {
      controller = Get.find<DictionaryController>();
    }
  }

  @override
  void dispose() {
    inputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Dictionary',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: inputController,
                style: theme.textTheme.bodyLarge,
                decoration: InputDecoration(
                  hintText: "Enter a word...",
                  labelText: null,
                  filled: true,
                  fillColor: theme.colorScheme.surface,
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: theme.primaryColor,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      Icons.arrow_forward_rounded,
                      color: theme.primaryColor,
                    ),
                    onPressed: () =>
                        controller.search(inputController.text.trim()),
                  ),
                ),
                onSubmitted: (val) => controller.search(val.trim()),
              ),
            ),
            const SizedBox(height: 24),
            Obx(() {
              if (controller.isLoading.value) {
                return const Center(child: CircularProgressIndicator());
              }
              return Expanded(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      // Results Area
                      if (controller.englishMeaning.isNotEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: theme.cardTheme.color,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.language_rounded,
                                    color: theme.primaryColor,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "English Definition",
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: theme.hintColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                controller.englishMeaning.value,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontSize: 16,
                                  height: 1.5,
                                ),
                              ),
                              if (controller.tamilMeaning.isNotEmpty) ...[
                                const SizedBox(height: 20),
                                Divider(color: theme.dividerColor),
                                const SizedBox(height: 20),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.translate_rounded,
                                      color: Colors.green,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      "Tamil Meaning",
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: theme.hintColor,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  controller.tamilMeaning.value,
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(
                                        fontSize: 18,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                ),
                              ],
                            ],
                          ),
                        ),

                      // History Area
                      if (controller.historyList.isNotEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Recent Searches",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: theme.hintColor,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: controller.clearHistory,
                                    child: const Text(
                                      "Clear All",
                                      style: TextStyle(color: Colors.redAccent),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: controller.historyList.map((word) {
                                return ActionChip(
                                  label: Text(word),
                                  backgroundColor: theme.colorScheme.surface,
                                  elevation: 1,
                                  onPressed: () {
                                    inputController.text = word;
                                    controller.search(word);
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
