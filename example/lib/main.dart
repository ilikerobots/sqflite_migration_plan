import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import 'src/entity.dart';
import 'src/migrating_repository.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final String title;

  MyHomePage({Key? key, this.title = "My App"}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    // get entities from db, with addl delay for demonstration
    Future<List<Entity>> _entities = Future.delayed(
        Duration(milliseconds: 500), MyRepository.instance.getEntities);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: FutureBuilder<List<Entity>>(
          future: _entities, // a previously-obtained Future<String> or null
          builder:
              (BuildContext context, AsyncSnapshot<List<Entity>> snapshot) {
            List<Widget> children;
            if (snapshot.hasData) {
              children = <Widget>[
                if ((snapshot.data?.length ?? 0) > 0)
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.all(24),
                      itemCount: snapshot.data?.length ?? 0,
                      itemBuilder: (BuildContext context, int index) {
                        return Container(
                          padding: EdgeInsets.all(8),
                          color: Colors.blue,
                          child: Center(
                              child: Column(
                            children: [
                              Text(
                                snapshot.data![index].name,
                                textScaleFactor: 1.3,
                                style: TextStyle(color: Colors.white),
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(4),
                                    color: Colors.amberAccent,
                                    child: Text(
                                      'Position: ${snapshot.data![index].position}',
                                    ),
                                  ),
                                  if (snapshot.data![index].hometown != null)
                                    Container(
                                      padding: EdgeInsets.all(4),
                                      color: Colors.tealAccent,
                                      child: Text(
                                        'Home: ${snapshot.data![index].hometown}',
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          )),
                        );
                      },
                      separatorBuilder: (BuildContext context, int index) =>
                          const Divider(),
                    ),
                  )
                else
                  Text("Database is empty")
              ];
            } else if (snapshot.hasError) {
              children = <Widget>[
                Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 60,
                ),
                if (snapshot.error is DatabaseException &&
                    (snapshot.error as DatabaseException).isNoSuchTableError())
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text('Error: Table does not exist!'),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text('Error: ${snapshot.error}'),
                  )
              ];
            } else {
              children = <Widget>[
                SizedBox(
                  child: CircularProgressIndicator(),
                  width: 60,
                  height: 60,
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Text('Awaiting result...'),
                )
              ];
            }
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: children,
              ),
            );
          },
        ),
      ),
    );
  }
}
