
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:english_words/english_words.dart';
import 'package:flutter/rendering.dart';

import 'package:flutter/widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:snapping_sheet/snapping_sheet.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:circular_profile_avatar/circular_profile_avatar.dart';


void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(App());
}

class App extends StatelessWidget {
  final Future<FirebaseApp> _initialization = Firebase.initializeApp();
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
                child: Text(snapshot.error.toString(),
                    textDirection: TextDirection.ltr)));
        }
      if (snapshot.connectionState == ConnectionState.done) {
        return MyApp();
      }
      return Center(child: CircularProgressIndicator());
        },
    );
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<UserRepository>(
        create: (_) => UserRepository.instance(),
        child: Consumer<UserRepository>(
            builder: (context, user, _) {
              return MaterialApp(
                title: 'Startup Name Generator',
                theme: ThemeData(
                    primaryColor: Colors.red,
                    canvasColor: Colors.white,
                    dividerColor: Colors.grey[350]
                ),
                home: RandomWords()
              );
            }
        )
    );
  }
}


class RandomWords extends StatefulWidget {
  @override
  _RandomWordsState createState() => _RandomWordsState();
}

class _RandomWordsState extends State<RandomWords> {
  final List<WordPair> _suggestions = <WordPair>[];
  final _saved = Set<WordPair>();
  final _removed = Set<WordPair>();
  final TextStyle _biggerFont = const TextStyle(fontSize: 18);
  SnappingSheetController _control = SnappingSheetController();
  @override
  Widget build(BuildContext context) {
    final user =  Provider.of<UserRepository>(context, listen: false);
    return Scaffold (
      appBar: AppBar(
        title: Text('Startup Name Generator'),
        actions: [
          IconButton(icon: Icon(Icons.list), onPressed: _pushSaved),
          user.status == Status.Authenticated?
          IconButton(icon: Icon(Icons.logout),
              onPressed: () {
            user.signOut();
            _saved.clear();
          })
          :IconButton(icon: Icon(Icons.login), onPressed: _loginScreen)
        ],
      ),
      body: user.status == Status.Authenticated?
          SnappingSheet(
        snappingSheetController: _control,
      snapPositions: [
        SnapPosition(
            positionPixel: 0,
            snappingCurve: Curves.easeInToLinear,
            snappingDuration: Duration(milliseconds: 20)
        ),
        SnapPosition(
            positionPixel: 120,
            snappingCurve: Curves.easeInToLinear,
            snappingDuration: Duration(milliseconds: 20)
        )
      ],
      sheetBelow: SnappingSheetContent(
          child: ListView(
            children: [
              Container(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(15,15,0,30),
                      child: CircularProfileAvatar(
                        null,
                        radius: 40,
                        child: user.userImageUrl != null ? Image.network(user.userImageUrl,fit: BoxFit.fitHeight)
                          :Icon(Icons.person),
                        backgroundColor: Colors.white70,
                        borderColor: Colors.red,
                        borderWidth: 2,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20,25,5,0),
                      child: Column(
                        children: [
                          Text(user.user.email,
                            style: TextStyle(fontSize: 16),
                          ),
                          Builder(
                            builder: (context) => FlatButton(
                            child: Text("Change avatar"),
                            height: 25,
                            textColor: Colors.white70,
                            color: Colors.teal,
                            onPressed: () async{
                              FilePickerResult result = await FilePicker.platform.pickFiles();
                              if(result != null) {
                                File file = File(result.files.single.path);
                                firebase_storage.Reference ref = firebase_storage.FirebaseStorage.instance
                                    .ref()
                                    .child('users')
                                    .child(user.user.uid.toString());

                                  await ref.putFile(file);
                                  await user._downloadAvatarImage();
                              } else {
                                Scaffold.of(context)
                                        .showSnackBar(SnackBar(
                                        content: Text("No image selected")));
                              }
                            },
                          )
                          )
                        ],
                      ),
                    )
                  ],
                ),
                color: Colors.white70,
              ),
            ],
          ),
          heightBehavior: SnappingSheetHeight.fit()
      ),

      sheetAbove: SnappingSheetContent(child: _buildSuggestions()),

      grabbingHeight: 50,
      grabbing: Container(
        child: Material(
          color: Colors.blueGrey[200],
          child: InkWell(
            onTap: (){
              if(_control.currentSnapPosition.positionPixel == 0)
                _control.snapToPosition(_control.snapPositions[1]);
              else
                _control.snapToPosition(_control.snapPositions[0]);
            },
            child: Padding(
              padding: const EdgeInsets.fromLTRB(15,0,15,0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Welcome back, " + emailController.text),
                  Icon(Icons.keyboard_arrow_up)
                ],
              ),
            ),
          ),
        ),
      ),
    )
          :_buildSuggestions()

    );
  }

  void _pushSaved() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) {
          final user =  Provider.of<UserRepository>(context, listen: false);
          return Scaffold(
              appBar: AppBar(
                title: Text('Saved Suggestions'),
              ),
              body: Builder(builder: (context) => ListView(children: ListTile.divideTiles(
                  context: context,
                  tiles: _saved.map(
                      (WordPair pair) {
                    return ListTile(
                      title: Text(
                        pair.asPascalCase,
                        style: _biggerFont,
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.delete_outline),
                        color: Colors.red,
                        onPressed: (){
                          setState(() {
                            _saved.remove(pair);
                            if (user.status == Status.Authenticated){
                              user._fireStoreRemove(pair);
                            }
                            else{
                              _removed.add(pair);
                            }
                            Navigator.of(context).pop();
                            _pushSaved();
                          });
                          final snackBar = SnackBar(
                            content: Text('Deletion is not implemented yet'),
                          );
                          Scaffold.of(context).showSnackBar(snackBar);
                        },
                      ),
                    );
                    },
                  )
                  ).toList()
              )
              )
          );
        },
      ),
    );
  }

  TextEditingController emailController = new TextEditingController();
  TextEditingController passwordController = new TextEditingController();
  TextEditingController passwordConfirmController = new TextEditingController();
  bool _validation = false;
  final _key = GlobalKey<ScaffoldState>();

  void _loginScreen() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          final user =  Provider.of<UserRepository>(context, listen: false);
          final emailText =
          Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                SizedBox(height:50),
                Flexible(
                  child:
                  Text('Welcome to Startup Names Generator, please log in below',
                    style: TextStyle(fontWeight: FontWeight.normal),
                    textAlign: TextAlign.left,
                  ),
              ),
                SizedBox(height:30),
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 0),
                  child: TextField(
                      controller: emailController,
                      textAlign: TextAlign.left,
                      maxLines: 1,
                      decoration: InputDecoration(
                      labelText: 'Email',
                    )
                  ),
                ),
                SizedBox(height:30),
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 0),
                  child: TextField(
                      controller: passwordController,
                      textAlign: TextAlign.left,
                      obscureText: true,
                      maxLines: 1,
                      decoration: InputDecoration(
                        labelText: 'Password',
                      )
                  )
                ),
                SizedBox(height:30),

                user.status == Status.Authenticating?
                Center(child: CircularProgressIndicator()):
                ButtonBar(
                  alignment: MainAxisAlignment.center,
                  children: <Widget>[
                  Builder(
                    builder: (context) => FlatButton(
                      child: Text('Log in'),
                      color: Colors.red,
                      textColor: Colors.white,
                      onPressed: () async {
                        if (!await user.signIn(emailController.text, passwordController.text))
                          {
                            final snackBar = SnackBar(
                                content: Text("There was an error logging into the app")
                            );
                            _key.currentState.showSnackBar(snackBar);
                          }
                        else
                          {
                            await user._addDocument();
                            _saveOnLogin(_saved);
                            _removeOnLogin(_removed);
                            user._getFireBaseSuggestions(_saved,_suggestions);
                            user._downloadAvatarImage();
                            Navigator.popUntil(_key.currentState.context, ModalRoute.withName(Navigator.defaultRouteName));
                          }
                      },
                      padding: EdgeInsets.fromLTRB(150, 10, 150, 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18.0),
                          side: BorderSide(color: Colors.red)
                      ),
                    )
                  ),
                  Builder(
                    builder: (context) => FlatButton(
                      child: Text("New user? Click to sign up"),
                      color: Colors.teal,
                      padding: EdgeInsets.fromLTRB(90, 10, 90, 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18.0),
                          side: BorderSide(color: Colors.teal)),
                      onPressed: (){
                        showModalBottomSheet(
                          isScrollControlled: true,
                            context: context,
                            builder: (context)=> Padding(
                              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                              child: Container(
                                height: 210,
                                child: ListView(
                                    children: [
                                      Column(
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(0,12,0,8),
                                            child: Text("Please confirm your password below:"),
                                          ),
                                          Divider(
                                            indent: 20,
                                            endIndent: 20,
                                          ),
                                          Padding(
                                            padding: const EdgeInsets.fromLTRB(20,0,20,0),
                                            child: TextField(
                                              controller: passwordConfirmController,
                                              textAlign: TextAlign.left,
                                              obscureText: true,
                                              maxLines: 1,
                                              decoration: InputDecoration(
                                                labelText: 'Password',
                                                fillColor: Colors.red,
                                                errorText: _validation ? null : 'Passwords must match',
                                              ),
                                            ),
                                          ),
                                          Divider(
                                            endIndent: 20,
                                            indent: 20,
                                          ),
                                          FlatButton(
                                            child: Text("Confirm"),
                                            color: Colors.teal,
                                            textColor: Colors.white,
                                            onPressed: ()async{
                                                FocusScope.of(context).requestFocus(FocusNode());
                                                if (passwordConfirmController.text == passwordController.text) {
                                                  _validation = true;
                                                  await user.signUp(emailController.text, passwordController.text);
                                                  await user._addDocument();
                                                  _saveOnLogin(_saved);
                                                  _removeOnLogin(_removed);
                                                  user._getFireBaseSuggestions(_saved,_suggestions);
                                                  Navigator.popUntil(_key.currentState.context, ModalRoute.withName(Navigator.defaultRouteName));
                                                }
                                                else
                                                  _validation = false;
                                            },
                                          )
                                        ],
                                      ),
                                    ]
                                )
                              ),
                            )
                        );
                      }
                    )
                  )
                  ]
                ),
              ]
          );

          return Scaffold(
            key: _key,
            appBar: AppBar(
              title: Text('Login'),
            ),
            body: emailText,
          );
        },
      ),
    );
  }

  Widget _buildSuggestions() {
    return ListView.builder(
        padding: const EdgeInsets.all(16),
        // The itemBuilder callback is called once per suggested
        // word pairing, and places each suggestion into a ListTile
        // row. For even rows, the function adds a ListTile row for
        // the word pairing. For odd rows, the function adds a
        // Divider widget to visually separate the entries. Note that
        // the divider may be difficult to see on smaller devices.
        itemBuilder: (BuildContext _context, int i) {
          // Add a one-pixel-high divider widget before each row
          // in the ListView.
          if (i.isOdd) {
            return Divider();
          }

          // The syntax "i ~/ 2" divides i by 2 and returns an
          // integer result.
          // For example: 1, 2, 3, 4, 5 becomes 0, 1, 1, 2, 2.
          // This calculates the actual number of word pairings
          // in the ListView,minus the divider widgets.
          final int index = i ~/ 2;
          // If you've reached the end of the available word
          // pairings...
          if (index >= _suggestions.length) {
            // ...then generate 10 more and add them to the
            // suggestions list.
            _suggestions.addAll(generateWordPairs().take(10));
          }
          return _buildRow(_suggestions[index]);
        }
    );
  }

  Widget _buildRow(WordPair pair) {
    final alreadySaved = _saved.contains(pair);
    final user =  Provider.of<UserRepository>(context, listen: false);
    return ListTile(
      title: Text(
        pair.asPascalCase,
        style: _biggerFont,
      ),

      trailing: Icon(
        alreadySaved ? Icons.favorite : Icons.favorite_border,
        color: alreadySaved ? Colors.red : null,
      ),

      onTap: () {
        setState(() {
          if (alreadySaved) {
            _saved.remove(pair);
            _removed.add(pair);
            if (user.status == Status.Authenticated) {
              user._fireStoreRemove(pair);
            }
          } else {
            _saved.add(pair);
            if(_removed.contains(pair)){
              _removed.remove(pair);
            }
            if (user.status == Status.Authenticated) {
              user._fireStoreInsert(pair);
            }
          }
        });
      },

    );
  }

  void _saveOnLogin(Set<WordPair> setSuggestions){
    final user =  Provider.of<UserRepository>(context,listen: false);
    List suggestions = setSuggestions.toList();
    for(var i = 0; i < suggestions.length; i++){
      user._fireStoreInsert(suggestions[i]);
    }
  }

  void _removeOnLogin(Set<WordPair> setToRemove){
    final user =  Provider.of<UserRepository>(context,listen: false);
    List toRemove = setToRemove.toList();
    for(var i = 0; i < toRemove.length; i++){
      user._fireStoreRemove(toRemove[i]);
    }
  }

}


enum Status { Uninitialized, Authenticated, Authenticating, Unauthenticated }

class UserRepository with ChangeNotifier {
  FirebaseAuth _auth;
  User _user;
  Status _status = Status.Unauthenticated;
  String userImageUrl;

  UserRepository.instance() : _auth = FirebaseAuth.instance {
    _auth.authStateChanges().listen(_authStateChanges);
  }

  Status get status => _status;

  User get user => _user;

  Future<bool> signUp(String _email, String _password) async {
    try {
      UserCredential userCredential =
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _email,
          password: _password,
      );
      _status = Status.Authenticated;
      notifyListeners();
      return await signIn(_email, _password);
    } catch (e) {
      _status = Status.Uninitialized;
      notifyListeners();
    }
  }

  Future<bool> signIn(String email, String password) async {
    try {
      _status = Status.Authenticating;
      notifyListeners();
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      _status = Status.Authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _status = Status.Unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Future signOut() async {
    _auth.signOut();
    _status = Status.Unauthenticated;
    userImageUrl = null;
    notifyListeners();
    return Future.delayed(Duration.zero);
  }

  Future<void> _authStateChanges(User firebaseUser) async {
    if (firebaseUser == null) {
      _status = Status.Unauthenticated;
    } else {
      _user = firebaseUser;
      _status = Status.Authenticated;
    }
    notifyListeners();
  }

  Future<List> _getFireBaseSuggestions(Set<WordPair> newSaved,
      List<WordPair> newSuggestions) async {
    final CollectionReference users = FirebaseFirestore.instance.collection(
        'users');
    final User user = _auth.currentUser;
    final uid = user.uid;
    var document = (await users.doc(uid.toString()).get());
    var savedWordsFromDb = (document['suggestions']);
    List<dynamic> savedFromDbToList = savedWordsFromDb;

    for (var i = 0; i < savedFromDbToList.length; i++) {
      var words = savedFromDbToList[i].split(
          new RegExp(r"(?<=[a-z])(?=[A-Z])"));

      WordPair pair = _findInSuggestions(savedFromDbToList[i], newSuggestions);
      if (pair != null) {
        newSaved.add(pair);
      }
      else {
        newSaved.add(WordPair(words[0], words[1]));
      }
    }
    notifyListeners();
  }

  void _fireStoreInsert(WordPair pair) async {
    final CollectionReference users = FirebaseFirestore.instance.collection(
        'users');
    final User user = _auth.currentUser;
    final uid = user.uid;

    users.doc(uid.toString()).update({
      'suggestions': FieldValue.arrayUnion([pair.asPascalCase])
    });
  }

  void _fireStoreRemove(WordPair pair) {
    final CollectionReference users = FirebaseFirestore.instance.collection(
        'users');
    final User user = _auth.currentUser;
    final uid = user.uid;

    users.doc(uid.toString()).update({
      'suggestions': FieldValue.arrayRemove([pair.asPascalCase])
    });
  }

  WordPair _findInSuggestions(String word, List<WordPair> newSuggestions) {
    for (int i = 0; i < newSuggestions.length; i++) {
      if (newSuggestions[i].asPascalCase == word) {
        return newSuggestions[i];
      }
    }
  }

  Future<void> _addDocument() async {
    final User user = _auth.currentUser;
    final uid = user.uid;

    var document = await FirebaseFirestore.instance.collection("users").doc(
        uid.toString()).get();
    if (!document.exists) {
      await FirebaseFirestore.instance.collection("users")
          .doc(uid.toString())
          .set({'suggestions': []});
    }
  }

  Future<void> _downloadAvatarImage() async {

    String newUrl;
    firebase_storage.Reference ref = firebase_storage.FirebaseStorage.instance
        .ref()
        .child('users').child(user.uid.toString());

    await ref.getDownloadURL().then((value) => newUrl = value);
    userImageUrl = newUrl;
    notifyListeners();
  }

}