import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mock_data/mock_data.dart';
import 'package:tree_view/tree_view.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({
    Key? key,
  }) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _nodes = <TreeNode<NodeData>>[];

  bool _showLines = false;
  final int _maxDepth = 8;
  void _generateNodes() {
    for (var i = 0; i < 5; i++) {
      _nodes.add(TreeNode(
          data: NodeData(value: mockString(8, 'A')),
          expanded: true,
          children: _generateChildrenNodes(3, 1)));
    }
  }

  List<TreeNode<NodeData>> _generateChildrenNodes(int count, int depth) {
    if (depth >= _maxDepth) {
      return [];
    }
    var children = <TreeNode<NodeData>>[];

    for (var i = 0; i < count; i++) {
      children.add(TreeNode(
          data: NodeData(value: mockName()),
          expanded: true,
          children: _generateChildrenNodes(
              depth > _maxDepth ~/ 3 && depth <= _maxDepth ~/ 2 ? 1 : 5,
              depth + 1)));
    }
    return children;
  }

  @override
  void initState() {
    _generateNodes();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tree View'),
      ),
      body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Switch(
                      value: _showLines,
                      onChanged: (b) {
                        setState(() {
                          _showLines = b;
                        });
                      }),
                  Text('Show Lines'),
                ],
              ),
              Expanded(
                child: TreeView<NodeData>(
                  nodes: _nodes,
                  showLines: _showLines,
                  nodeItemBuilder: (
                    context,
                    node,
                  ) {
                    return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            node.children.isNotEmpty
                                ? IconButton(
                                    iconSize: 12,
                                    splashRadius: 16,
                                    padding: EdgeInsets.zero,
                                    constraints:
                                        BoxConstraints.tight(Size(30, 30)),
                                    icon: Icon(node.expanded
                                        ? Icons.remove
                                        : Icons.add),
                                    onPressed: () {
                                      node.expanded = !node.expanded;
                                    },
                                  )
                                : const SizedBox(
                                    width: 12,
                                  ),
                            Text(
                              node.data.value,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black,
                              ),
                              overflow: TextOverflow.ellipsis,
                            )
                          ],
                        ));
                  },
                ),
              ),
            ],
          )),
    );
  }
}

class NodeData {
  NodeData({this.value = ''});
  final String value;
}

class AddNode extends NodeData {}

enum NodeType {
  object,
  value,
}
