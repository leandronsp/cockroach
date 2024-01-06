// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:convert';

class Product {
  const Product({required this.name});

  final String name;
}

typedef CartChangedCallback = Function(Product product, bool inCart);

class ShoppingListItem extends StatelessWidget {
  ShoppingListItem({
    required this.product,
    required this.inCart,
    required this.onCartChanged,
  }) : super(key: ObjectKey(product));

  final Product product;
  final bool inCart;
  final CartChangedCallback onCartChanged;

  Color _getColor(BuildContext context) {
    // The theme depends on the BuildContext because different
    // parts of the tree can have different themes.
    // The BuildContext indicates where the build is
    // taking place and therefore which theme to use.

    return inCart //
        ? Colors.black54
        : Theme.of(context).primaryColor;
  }

  TextStyle? _getTextStyle(BuildContext context) {
    if (!inCart) return null;

    return const TextStyle(
      color: Colors.black54,
      decoration: TextDecoration.lineThrough,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: () {
        onCartChanged(product, inCart);
      },
      leading: CircleAvatar(
        backgroundColor: _getColor(context),
        child: Text(product.name[0]),
      ),
      title: Text(
        product.name,
        style: _getTextStyle(context),
      ),
    );
  }
}

class ShoppingList extends StatefulWidget {
  const ShoppingList({required this.products, super.key});

  final List<Product> products;

  // The framework calls createState the first time
  // a widget appears at a given location in the tree.
  // If the parent rebuilds and uses the same type of
  // widget (with the same key), the framework re-uses
  // the State object instead of creating a new State object.

  @override
  State<ShoppingList> createState() => _ShoppingListState();
}

class _ShoppingListState extends State<ShoppingList> {
  final _shoppingCart = <Product>{};

  void _handleCartChanged(Product product, bool inCart) {
    print("Product: ${product.name}, inCart: $inCart");

    setState(() {
      // When a user changes what's in the cart, you need
      // to change _shoppingCart inside a setState call to
      // trigger a rebuild.
      // The framework then calls build, below,
      // which updates the visual appearance of the app.

      if (!inCart) {
        _shoppingCart.add(product);
      } else {
        _shoppingCart.remove(product);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping List'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: widget.products.map((product) {
          return ShoppingListItem(
            product: product,
            inCart: _shoppingCart.contains(product),
            onCartChanged: _handleCartChanged,
          );
        }).toList(),
      ),
    );
  }
}

class MySwitch extends StatelessWidget {
  const MySwitch({required this.isDarkMode, required this.onSwitch, super.key});
  final Function(bool) onSwitch;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return Switch(
      value: isDarkMode,
      activeColor: Colors.purple,
      onChanged: onSwitch,
    );
  }
}

class ItemsDatabase {
  const ItemsDatabase({ required this.onItemsFetched });
  final Function(List<String>) onItemsFetched;

  Future<void> saveItems(List<String> items) async {
    final db = await openDatabase(
      join(await getDatabasesPath(), 'items_database.db'),
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE items(name TEXT)',
        );
      },
      version: 1,
    );

    await db.transaction((txn) async {
      for (final item in items) {
        await txn.rawInsert(
          'INSERT INTO items(name) VALUES("$item")',
        );
      }
    });

    await db.close();
  }

  Future<void> loadItems() async {
    final db = await openDatabase(
      join(await getDatabasesPath(), 'items_database.db'),
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE items(name TEXT)',
        );
      },
      version: 1,
    );

    final List<Map<String, dynamic>> maps = await db.query('items');

    final List<String> items = List.generate(maps.length, (i) {
      return maps[i]['name'] as String;
    });

    await db.close();

    onItemsFetched(items);
  }
}

class ItemsAPI {
  const ItemsAPI({required this.onItemsFetched});
  final Function(List<String>) onItemsFetched;

  Future<void> downloadData() async {
    var response = await http.get(Uri.parse('http://localhost:8088/items'));
    print("Response: ${response.body}");

    var data = jsonDecode(response.body) as Map<String, dynamic>;
    var list = data['items'] as List<dynamic>;
    List<String> items = [];

    for (final item in list) {
      items.add(item as String);
    }

    var itemsDatabase = ItemsDatabase(onItemsFetched: onItemsFetched);
    itemsDatabase.saveItems(items);
    itemsDatabase.loadItems();
  }
}

class MyDownload extends StatelessWidget {
  const MyDownload({required this.onItemsFetched, super.key});
  final Function(List<String>) onItemsFetched;

  Future<void> _downloadData() async {
    final api = ItemsAPI(onItemsFetched: onItemsFetched);
    api.downloadData();
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: _downloadData,
      child: const Icon(Icons.download),
    );
  }
}

class MyApp extends StatefulWidget {
  const MyApp({ super.key });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isDarkMode = false;
  List<String> _items = [];

  @override
  void initState() {
    super.initState();
    _loadPreferences();

    var itemsDatabase = ItemsDatabase(onItemsFetched: _handleItemsFetched);
    itemsDatabase.loadItems();
  }

  void _handleItemsFetched(List<String> items) {
    setState(() {
      _items = items;
    });
  }

  void _handleOnSwitch(bool isDarkMode) {
    setState(() {
      _isDarkMode = isDarkMode;
      _savePreferences();
    });
  }

  Future<void> _loadPreferences() async {
    print('Loading Preferences');
    final prefs = await SharedPreferences.getInstance();
    print("Dark Mode: ${prefs.getBool('darkMode')}");

    setState(() {
      _isDarkMode = prefs.getBool('darkMode') ?? false;
    });
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    print("Saving Dark Mode: $_isDarkMode");
    prefs.setBool('darkMode', _isDarkMode);
  }

  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shopping App',
      theme: ThemeData(
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
      ),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: Scaffold(
        body: ShoppingList(
          products: _items.map((item) {
            return Product(name: item);
          }).toList()
        ),
        bottomNavigationBar: BottomAppBar(
          child: MySwitch(isDarkMode: _isDarkMode, onSwitch: _handleOnSwitch),
        ),
        floatingActionButton: MyDownload(
          onItemsFetched: _handleItemsFetched
        ),
      ),
    );
  }
}

void main() {
  runApp(const MyApp());
}
