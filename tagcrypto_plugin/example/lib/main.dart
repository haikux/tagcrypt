import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';

import 'package:tagcrypto_plugin/tagcrypto_plugin.dart';
import 'package:nfc_in_flutter/nfc_in_flutter.dart';
import 'package:tagcrypto_plugin_example/db_utils.dart';


void main() async {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _payload = '{}'; // Golang interface IO data
  String _tagkey = ""; //  Scanned NFC data
  String _datago = "";
  String _displayString = ""; // App output information

  // Control data and password text fields
  final dataController = TextEditingController(); 
  final pwdController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    // Clean up the controller when the widget is disposed.
    dataController.dispose();
    pwdController.dispose();
    super.dispose();
  }

  Future<void> writeTag(String tagkey) async{
      /*
      Asynchronous write to NFC tag.
      Uses nfc_in_flutter plugin
      */
      NDEFMessage newMessage = NDEFMessage.withRecords([NDEFRecord.text(tagkey)]);
      var result = await NFC.writeNDEF(newMessage, once:true).first;
      print("Tag content: {$result}");
    }

    Future<void> readTag() async{
      /*
      Asynchronous read from NFC tag
      Uses nfc_in_flutter plugin
      Note: plugin only supports data in NDEF format
      */
      NDEFMessage message = await NFC.readNDEF(once:true).first;
      String response = message.data.toString();
      if (response.isNotEmpty) {
        setState(() {
          _tagkey = response;
          _displayString = "Scan complete";
        });
      }
    }

    Future<void> tagCryptoFunc(String payload) async {
      // Interfaces with tagcrypt Golang function
      String response;
      try{
        String arguments = payload;
        response = await TagcryptoPlugin.tagcrypt(arguments); // Call Go tagcrypt function
      } on Exception catch (e){
        print("Exception connectiong to Tagcrypto: ${e}");
      }
      if (response != null){
        setState(() {
          var argumentsJSON = json.decode(response);
          setAppOutput(argumentsJSON["data"]);
          // If user inserts new data, perform encryption and write hashed key on NFC tag
          if (argumentsJSON["tag_operation"] == "insert"){
              _tagkey = argumentsJSON["tag_key"].toString();
              final userData = KeyData(
                id: 0,
                datatype: 'web',
                data: argumentsJSON["data"],
              );
              DBUtils.instance.dbWrite(userData);
              print("Wrote to db {$userData}");
              setAppOutput("user key: "+argumentsJSON["user_key"]);
              writeTag(_tagkey); 
            }
        });
      }
    }

    void setAppOutput(String payload){
      // Display displayString in App as output
      setState(() {
        _displayString = payload;
      });
    }
    
    @override
    Widget build(BuildContext context) {
      return MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            title: const Text('Key Manager'),
          ),
          body: 
            Form(
            key: _formKey,
            child: 
            Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: <Widget>[
              TextFormField(
                controller: dataController,
                decoration: InputDecoration(
                  labelText: 'Data',
                  hintText: 'Enter Data to encrypt',
                  suffixIcon: IconButton(
                    onPressed: () => dataController.clear(),
                    icon: Icon(Icons.clear),
                  )
                ),
              ),

              TextFormField(
                controller: pwdController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  hintText: 'Enter your key',
                  suffixIcon: IconButton(
                    onPressed: () => pwdController.clear(),
                    icon: Icon(Icons.clear),
                  )
                ),
                validator: (password){
                  if (password.length < 6){
                    return 'password must be of length 6 or more';
                  }
                  return null;
                },
              ),
              InkWell(
                onTap: (){
                  if (_formKey.currentState.validate()){
                    readTag();
                    // NFC scan started
                    // Display scan status on App status box
                    setAppOutput("Tap NFC tag");
                  }
                },
                // App output window
                child: new Container(
                margin: const EdgeInsets.only(top:40,left: 20.0, right: 20.0),
                height: 250,
                width: 300,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.blue,
                    width: 3,
                  ),
                ),
                
                child: Center(
                  child: Text(
                    "$_displayString",
                    style: TextStyle(fontSize: 25))
                )
              ),
              )],
            ),
          ),
          
          // Button to start encryption
          floatingActionButton: FloatingActionButton(
          onPressed: (){
            String userData = dataController.text;
            String userKey = pwdController.text;    
            if (userKey.isNotEmpty) {
              // if only pwd is present, decrypt on floating button press
              if (userData.isNotEmpty){
                // if both password and data is present, encrypt data with user pwd
                _datago = userData;
                _payload = '{"tag_operation":"insert","user_key":"$userKey","tag_key":"","data":"$_datago"}';
              }else{
                // Read encrypted data from DB
                Future<KeyData> dbResult = DBUtils.instance.dbRead();
                dbResult.then((value) => _datago = value.data);
                print("Fututre DB result {$_datago}");
                _payload = '{"tag_operation":"get","user_key":"$userKey","tag_key":"$_tagkey","data":"$_datago"}';
              }
              // Call tagcrypto function in Go to wither encrypt/decrypt data based on tag_operation
              tagCryptoFunc(_payload);
              
            }
            },
          tooltip: 'Encrypt',
          child: Icon(Icons.enhanced_encryption),
        ),
        /////
        ),
      );
    }
    
  }