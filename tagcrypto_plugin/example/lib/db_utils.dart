import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';


class KeyData{
  final int id;
  final String datatype;
  final String data;
  KeyData({this.id,this.datatype,this.data});

  Map<String,dynamic> toMap(){
return {
    'id': id,
    'datatype': datatype,
    'data': data,
    };
  }
}

class DBUtils{

  DBUtils._();

  static const databaseName = 'physec_keymgmt.db';
  static final DBUtils instance = DBUtils._();
  static Database _database;

  Future<Database> get database async {
    if (_database == null) {
      return await initDB();
    }
    return _database;
  }

  initDB() async {
    return await openDatabase(join(await getDatabasesPath(), databaseName),
        version: 1, onCreate: (Database db, int version) async {
      await db.execute(
          "CREATE TABLE userkeystorage(id INTEGER PRIMARY KEY, datatype TEXT, data TEXT)");
    });
  }

  // Write Encrypted JWT token
  Future<void> dbWrite(KeyData key) async{
    final Database db = await database;
    await db.insert(
      'userkeystorage',
      key.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Read encrypted token
  Future <KeyData> dbRead() async {
    // Get a reference to the database.
    final Database db = await database;

    // Query the table for all The Dogs.
    final List<Map<String, dynamic>> maps = await db.query('userkeystorage');

  return KeyData(
    id: maps[0]['id'],
    datatype: maps[0]['datatype'],
    data: maps[0]['data'],
  );
   // Convert the List<Map<String, dynamic> into a List<Dog>.
  //  return List.generate(0, (i) {
  //     return KeyData(
  //       id: maps[i]['id'],
  //       datatype: maps[i]['datatype'],
  //       data: maps[i]['data'],
  //     );
  //   });
}
}