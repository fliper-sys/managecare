import 'package:flutter/material.dart';

class CocktailMenuScreen extends StatefulWidget {
  const CocktailMenuScreen({super.key});

  @override
  State<CocktailMenuScreen> createState() => _CocktailMenuScreenState();
}

class _CocktailMenuScreenState extends State<CocktailMenuScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cocktail Menu')),
      body: const Center(child: Text('Cocktail Menu Screen')),
    );
  }
}

