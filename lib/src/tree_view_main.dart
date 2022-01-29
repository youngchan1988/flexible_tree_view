// Copyright (c) 2022, the tree_view project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'package:flutter/material.dart';

import 'reorderable_list_ex.dart';
import 'package:ulid/ulid.dart';

typedef NodeItemBuilder<T> = Widget Function(
    BuildContext context, TreeNode<T> node);

typedef WillReorder<T> = bool Function(
    TreeNode<T> orderNode, TreeNode<T> currentNode);

typedef OnReorder<T> = void Function(
    TreeNode<T> orderNode, TreeNode<T> currentNode);

class TreeView<T> extends StatefulWidget {
  const TreeView(
      {Key? key,
      required this.nodes,
      this.maxNodeWidth = 300,
      required this.nodeItemBuilder,
      this.showLines = false,
      this.willRecorder,
      this.onReorder})
      : super(key: key);

  /// The max width of node.
  final double maxNodeWidth;

  final List<TreeNode<T>> nodes;

  /// Node item widget.
  final NodeItemBuilder<T> nodeItemBuilder;

  /// Show the lines of parent -> child.
  final bool showLines;

  /// Todo: support reorder in different nodes.
  final WillReorder<T>? willRecorder;

  /// Todo: support reorder in different nodes.
  final OnReorder<T>? onReorder;

  @override
  _TreeViewState createState() => _TreeViewState<T>();
}

class _TreeViewState<T> extends State<TreeView<T>> implements TreeObserver {
  final List<TreeNode<T>> _listShowNodes = [];
  final _horizontalScrollController = ScrollController();

  final StreamController<List<TreeNode<T>>> _treeController =
      StreamController();

  //Max depth is to dynamic evaluate the tree width.
  int _maxDepth = 0;

  @override
  void initState() {
    _updateShowNodes();
    super.initState();
  }

  @override
  void didUpdateWidget(TreeView<T> oldWidget) {
    _updateShowNodes();
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void rebuild() {
    _updateShowNodes();
    _treeController.sink.add(_listShowNodes);
  }

  void _updateShowNodes() {
    var nodes = <TreeNode<T>>[];
    for (var node in widget.nodes) {
      _buildShowNodes(node, nodes);
    }

    _listShowNodes.clear();
    _listShowNodes.addAll(nodes);
  }

  void _buildShowNodes(
    TreeNode<T> source,
    List<TreeNode<T>> buildNodeList,
  ) {
    source._treeObserver = this;
    buildNodeList.add(source);

    if (source.children.isNotEmpty && source.expanded) {
      for (var child in source.children) {
        _buildShowNodes(child, buildNodeList);
      }
    }
    if (source.depth > _maxDepth) {
      //更新最大层级
      _maxDepth = source.depth;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _horizontalScrollController,
      showTrackOnHover: true,
      child: SingleChildScrollView(
        controller: _horizontalScrollController,
        scrollDirection: Axis.horizontal,
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: (_maxDepth * 16.0 + widget.maxNodeWidth),
            padding: const EdgeInsets.only(bottom: 16),
            alignment: Alignment.centerLeft,
            child: StreamBuilder<List<TreeNode<T>>>(
              initialData: _listShowNodes,
              stream: _treeController.stream,
              builder: (context, snapshot) {
                assert(snapshot.data != null);
                var showNodes = snapshot.data!;

                return ReorderableListViewEx.builder(
                  scrollController: ScrollController(),
                  isItemReorderable: (index) {
                    var node = showNodes[index];
                    // log('Item reorderable: ${node.reorderable}');
                    return node.reorderable;
                  },
                  onReorder: (oldIndex, newIndex) {
                    var orderNode = showNodes[oldIndex];
                    var orderUpper = false;
                    if (oldIndex < newIndex) {
                      newIndex -= 1;
                      orderUpper = true;
                    }
                    var currentNode = showNodes[newIndex];
                    var canReorder =
                        widget.willRecorder?.call(orderNode, currentNode) ??
                            false;
                    if (canReorder) {
                      if (orderNode.parent == currentNode.parent) {
                        if (currentNode.parent != null) {
                          var children = orderNode.parent!.children;
                          children.manulSort(currentNode, orderNode);
                          rebuild();
                        } else if (widget.nodes.contains(orderNode) &&
                            widget.nodes.contains(currentNode)) {
                          widget.nodes.manulSort(currentNode, orderNode);
                          rebuild();
                        }
                      } else {
                        if (currentNode.parent != null) {
                          if (orderNode.parent != null) {
                            orderNode._deleteSelf();
                          } else if (widget.nodes.contains(orderNode)) {
                            widget.nodes.remove(orderNode);
                          }

                          var children = currentNode.parent!.children;
                          var index = children.indexOf(currentNode);
                          if (orderUpper) {
                            currentNode.parent!
                                ._insertNode(index + 1, orderNode);
                          } else {
                            currentNode.parent!._insertNode(index, orderNode);
                          }
                          rebuild();
                        } else if (widget.nodes.contains(currentNode)) {
                          if (orderNode.parent != null) {
                            orderNode._deleteSelf();
                          }
                          var index = widget.nodes.indexOf(currentNode);
                          if (orderUpper) {
                            widget.nodes.insert(index + 1, orderNode);
                          } else {
                            widget.nodes.insert(index, orderNode);
                          }
                          rebuild();
                        }
                      }
                      widget.onReorder?.call(orderNode, currentNode);
                    }
                  },
                  itemCount: showNodes.length,
                  itemBuilder: (context, index) {
                    var node = showNodes[index];
                    return TreeNodeWidget<T>(
                      key: GlobalObjectKey(node.key),
                      node: node,
                      builder: widget.nodeItemBuilder,
                      showLines: widget.showLines,
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class TreeNodeWidget<T> extends StatefulWidget {
  const TreeNodeWidget({
    Key? key,
    required this.node,
    required this.builder,
    required this.showLines,
  }) : super(key: key);

  final TreeNode<T> node;
  final NodeItemBuilder<T> builder;
  final bool showLines;

  @override
  _TreeNodeWidgetState<T> createState() => _TreeNodeWidgetState<T>();
}

class _TreeNodeWidgetState<T> extends State<TreeNodeWidget<T>>
    with SingleTickerProviderStateMixin {
  late Animation<double> _fadeAnim;
  late AnimationController _fadeIn;
  @override
  void initState() {
    widget.node.addListener(_onNodeChanged);

    //Fade in
    _fadeIn = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200), value: 0);
    _fadeAnim = CurveTween(curve: Curves.easeIn).animate(_fadeIn);
    _fadeIn.forward(from: 0);
    super.initState();
  }

  @override
  void didUpdateWidget(covariant TreeNodeWidget<T> oldWidget) {
    if (widget.node != oldWidget.node) {
      widget.node.addListener(_onNodeChanged);
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    widget.node.removeListener(_onNodeChanged);
    _fadeIn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var verticalLines = <Widget>[];
    var parent = widget.node.parent;
    while (widget.showLines && parent != null) {
      //Only draw line when the children > 1
      if (parent.children.length > 1) {
        verticalLines.add(
          Positioned(
            top: 0,
            bottom: 0,
            left: parent.depth * 16,
            child: const VerticalDivider(
              color: Colors.black54,
              width: 1,
            ),
          ),
        );
      }
      parent = parent.parent;
    }

    return Stack(
      children: [
        FadeTransition(
          opacity: _fadeAnim,
          child: Padding(
            padding: EdgeInsets.only(left: widget.node.depth * 16.0),
            child: widget.builder(context, widget.node),
          ),
        ),
        if (widget.showLines &&
            widget.node.depth > 0 &&
            ((widget.node.parent?.children.length ?? 0) > 1))
          Positioned(
              top: 0,
              bottom: 0,
              left: (widget.node.depth - 1) * 16,
              width: 16,
              child: const Divider(
                color: Colors.black54,
              )),
        ...verticalLines
      ],
    );
  }

  void _onNodeChanged() {
    setState(() {});
  }
}

///
class TreeNode<T> with ChangeNotifier {
  TreeNode({
    String? key,
    required T data,
    bool? expanded,
    this.reorderable = false,
    TreeNode<T>? parent,
    List<TreeNode<T>>? children,
  })  : _data = data,
        key = key ?? Ulid().toCanonical() {
    if (parent != null) {
      _parent = parent;
      _depth = parent._depth + 1;
    }
    if (expanded != null) {
      _expanded = expanded;
    }
    if (children?.isNotEmpty == true) {
      children!.forEach((element) {
        element.parent = this;
      });
      _children = children;
    }
  }

  final String key;

  TreeObserver? _treeObserver;

  /// The node's data.
  T _data;

  T get data => _data;

  set data(T d) {
    _data = d;
    notifyListeners();
  }

  ///Is the node can reorder.
  final bool reorderable;

  /// Is the node have expanded.
  bool _expanded = false;

  bool get expanded => _expanded;

  set expanded(bool expand) {
    _expanded = expand;
    _treeObserver?.rebuild();
  }

  /// Current node's depth in the tree
  int _depth = 0;

  int get depth => _depth;

  set depth(int depth) {
    _depth = depth;
    _children?.forEach((element) {
      element.depth = _depth + 1;
    });
  }

  /// The parent node.
  TreeNode<T>? _parent;

  TreeNode<T>? get parent => _parent;

  set parent(TreeNode<T>? node) {
    _parent = node;
    if (node != null) {
      depth = node.depth + 1;
    } else {
      _depth = 0;
    }
  }

  /// The children nodes.
  List<TreeNode<T>>? _children;

  List<TreeNode<T>> get children => _children ??= [];

  void notifyDataChanged() {
    notifyListeners();
  }

  void addNode(TreeNode<T> node) {
    _addNode(node);
    _treeObserver?.rebuild();
  }

  void _addNode(TreeNode<T> node) {
    node.parent = this;
    children.add(node);
  }

  void insertNode(int index, TreeNode<T> node) {
    _insertNode(index, node);
    _treeObserver?.rebuild();
  }

  void _insertNode(int index, TreeNode<T> node) {
    node.parent = this;
    children.insert(index, node);
  }

  void removeNode(TreeNode<T> node) {
    if (children.contains(node)) {
      _removeNode(node);
      _treeObserver?.rebuild();
    }
  }

  void _removeNode(TreeNode<T> node) {
    node.parent = null;
    children.remove(node);
  }

  void deleteSelf() {
    _deleteSelf();
    notifyDataChanged();
  }

  void _deleteSelf() {
    _children?.clear();
    _parent?.children.remove(this);
    _parent = null;
  }

  TreeNode<T> copyWith(
      {String? key,
      T? data,
      bool? expanded,
      bool? selected,
      bool? reorderable,
      TreeNode<T>? parent,
      List<TreeNode<T>>? children}) {
    var copyNode = TreeNode(
      key: key ?? this.key,
      data: data ?? this.data,
      expanded: expanded ?? this.expanded,
      reorderable: reorderable ?? this.reorderable,
      parent: parent ?? _parent,
    );
    _children?.forEach((element) {
      copyNode.children.add(element.copyWith(parent: copyNode));
    });
    return copyNode;
  }
}

abstract class TreeObserver {
  void rebuild();
}

extension ListEx on List {
  void manulSort(dynamic currentItem, dynamic sortItem) {
    var index1 = indexOf(currentItem);
    if (index1 < 0) {
      return;
    }
    var index2 = indexOf(sortItem);
    if (index2 < 0) {
      return;
    }
    remove(sortItem);
    var index = indexOf(currentItem);
    if (index1 < index2) {
      insert(index, sortItem);
    } else {
      insert(index + 1, sortItem);
    }
  }
}
