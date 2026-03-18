import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;
import 'dart:io';


Database? globalDb;

Future<Database> getDatabase() async {
  if (globalDb != null) return globalDb!;

  String path = p.join(await getDatabasesPath(), 'lab3_v2.db');
  globalDb = await openDatabase(
    path,
    version: 1,
    onCreate: (db, version) async {

      await db.execute(
        'CREATE TABLE users (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT, age INTEGER)',
      );

      await db.execute(
        'CREATE TABLE passwords ('
        '  id INTEGER PRIMARY KEY AUTOINCREMENT,'
        '  user_id INTEGER,'
        '  service_name TEXT,'
        '  username TEXT,'
        '  password_value TEXT'
        ')',
      );
    },
  );
  return globalDb!;
}

void main() {

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Lab 3 - SQLite',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const UsersScreen(),
    );
  }
}



class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  Database? db;
  List<Map<String, dynamic>> users = [];

  final nameController = TextEditingController();
  final ageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    initDb();
  }

  Future<void> initDb() async {
    db = await getDatabase();
    loadUsers();
  }

  Future<void> loadUsers() async {
    if (db == null) return;
    final result = await db!.query('users');
    setState(() {
      users = result;
    });
  }

  Future<void> addUser() async {
    if (db == null) return;
    String name = nameController.text.trim();
    String ageText = ageController.text.trim();

    if (name.isEmpty || ageText.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заповніть ім\'я та вік!')),
      );
      return;
    }

    int age = int.tryParse(ageText) ?? 0;
    await db!.insert('users', {'name': name, 'age': age});

    nameController.clear();
    ageController.clear();
    loadUsers();
  }

  Future<void> deleteUser(int id) async {
    if (db == null) return;
  
    await db!.delete('passwords', where: 'user_id = ?', whereArgs: [id]);
    await db!.delete('users', where: 'id = ?', whereArgs: [id]);
    loadUsers();
  }

  void showEditDialog(int id, String currentName, int currentAge) {
    nameController.text = currentName;
    ageController.text = currentAge.toString();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Редагувати користувача'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Ім\'я'),
            ),
            TextField(
              controller: ageController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Вік'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              nameController.clear();
              ageController.clear();
              Navigator.pop(ctx);
            },
            child: const Text('Скасувати'),
          ),
          ElevatedButton(
            onPressed: () async {
              await db!.update(
                'users',
                {
                  'name': nameController.text.trim(),
                  'age': int.tryParse(ageController.text.trim()) ?? 0,
                },
                where: 'id = ?',
                whereArgs: [id],
              );
              nameController.clear();
              ageController.clear();
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              loadUsers();
            },
            child: const Text('Зберегти'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Користувачі'),
      ),
      body: Column(
        children: [
          
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Ім\'я',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: ageController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Вік',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: addUser,
                    child: const Text('Додати користувача'),
                  ),
                ),
              ],
            ),
          ),

          const Divider(thickness: 2),


          Expanded(
            child: users.isEmpty
                ? const Center(child: Text('Список порожній. Додайте користувача.'))
                : ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final user = users[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.person),
                          ),
                          title: Text(user['name']),
                          subtitle: Text('Вік: ${user['age']}'),
                          
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              
                              IconButton(
                                icon: const Icon(Icons.lock_open,
                                    color: Colors.green),
                                tooltip: 'Паролі',
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => PasswordsScreen(
                                        userId: user['id'],
                                        userName: user['name'],
                                      ),
                                    ),
                                  );
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => showEditDialog(
                                  user['id'],
                                  user['name'],
                                  user['age'],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => deleteUser(user['id']),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}



class PasswordsScreen extends StatefulWidget {
  final int userId;
  final String userName;

  const PasswordsScreen({
    super.key,
    required this.userId,
    required this.userName,
  });

  @override
  State<PasswordsScreen> createState() => _PasswordsScreenState();
}

class _PasswordsScreenState extends State<PasswordsScreen> {
  Database? db;
  List<Map<String, dynamic>> passwords = [];

  List<int> visibleIds = [];

  final serviceController = TextEditingController();
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    initDb();
  }

  Future<void> initDb() async {
    db = await getDatabase();
    loadPasswords();
  }


  Future<void> loadPasswords() async {
    if (db == null) return;
    final result = await db!.query(
      'passwords',
      where: 'user_id = ?',
      whereArgs: [widget.userId],
    );
    setState(() {
      passwords = result;
    });
  }

  Future<void> addPassword() async {
    if (db == null) return;
    String service = serviceController.text.trim();
    String username = usernameController.text.trim();
    String password = passwordController.text.trim();

    if (service.isEmpty || username.isEmpty || password.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заповніть всі поля!')),
      );
      return;
    }

    await db!.insert('passwords', {
      'user_id': widget.userId,     
      'service_name': service,
      'username': username,
      'password_value': password,
    });

    serviceController.clear();
    usernameController.clear();
    passwordController.clear();
    loadPasswords();
  }

  Future<void> deletePassword(int id) async {
    if (db == null) return;
    await db!.delete('passwords', where: 'id = ?', whereArgs: [id]);
    visibleIds.remove(id);
    loadPasswords();
  }

  void toggleVisibility(int id) {
    setState(() {
      if (visibleIds.contains(id)) {
        visibleIds.remove(id);
      } else {
        visibleIds.add(id);
      }
    });
  }

  void showEditDialog(int id, String service, String username, String pass) {
    serviceController.text = service;
    usernameController.text = username;
    passwordController.text = pass;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Редагувати запис'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: serviceController,
              decoration:
                  const InputDecoration(labelText: 'Назва сервісу'),
            ),
            TextField(
              controller: usernameController,
              decoration:
                  const InputDecoration(labelText: 'Логін / Email'),
            ),
            TextField(
              controller: passwordController,
              decoration: const InputDecoration(labelText: 'Пароль'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              serviceController.clear();
              usernameController.clear();
              passwordController.clear();
              Navigator.pop(ctx);
            },
            child: const Text('Скасувати'),
          ),
          ElevatedButton(
            onPressed: () async {
              await db!.update(
                'passwords',
                {
                  'service_name': serviceController.text.trim(),
                  'username': usernameController.text.trim(),
                  'password_value': passwordController.text.trim(),
                },
                where: 'id = ?',
                whereArgs: [id],
              );
              serviceController.clear();
              usernameController.clear();
              passwordController.clear();
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              loadPasswords();
            },
            child: const Text('Зберегти'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Паролі — ${widget.userName}'),
      ),
      body: Column(
        children: [

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: serviceController,
                  decoration: const InputDecoration(
                    labelText: 'Сервіс (Google, Instagram...)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Логін або Email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Пароль',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: addPassword,
                    child: const Text('Зберегти пароль'),
                  ),
                ),
              ],
            ),
          ),

          const Divider(thickness: 2),


          Expanded(
            child: passwords.isEmpty
                ? const Center(child: Text('Немає збережених паролів'))
                : ListView.builder(
                    itemCount: passwords.length,
                    itemBuilder: (context, index) {
                      final item = passwords[index];
                      int id = item['id'];
                      bool isVisible = visibleIds.contains(id);

                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        child: ListTile(
                          leading:
                              const CircleAvatar(child: Icon(Icons.lock)),
                          title: Text(
                            item['service_name'],
                            style: const TextStyle(
                                fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Логін: ${item['username']}'),
                              GestureDetector(
                                onTap: () => toggleVisibility(id),
                                child: Text(
                                  isVisible
                                      ? 'Пароль: ${item['password_value']}'
                                      : 'Пароль: ••••••••',
                                  style: TextStyle(
                                    color: isVisible
                                        ? Colors.black87
                                        : Colors.grey,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit,
                                    color: Colors.blue),
                                onPressed: () => showEditDialog(
                                  id,
                                  item['service_name'],
                                  item['username'],
                                  item['password_value'],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete,
                                    color: Colors.red),
                                onPressed: () => deletePassword(id),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
