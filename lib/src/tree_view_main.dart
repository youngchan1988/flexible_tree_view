// Copyright (c) 2022, the flexible_tree_view project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:flutter/material.dart';
import 'reorderable_list_ex.dart';

typedef NodeItemBuilder<T> = Widget Function(
    BuildContext context, TreeNode<T> node);

typedef NodeItemBackground<T> = Color? Function(
    BuildContext context, TreeNode<T> node);

typedef WillReorder<T> = bool Function(
    TreeNode<T> orderNode, TreeNode<T> currentNode);

typedef OnReorder<T> = void Function(
    TreeNode<T> orderNode, TreeNode<T> currentNode);

class FlexibleTreeView<T> extends StatefulWidget {
  const FlexibleTreeView(
      {Key? key,
      required this.nodes,
      this.nodeWidth = 300,
      this.scrollable = true,
      this.nodeItemBuilder,
      this.nodeItemBackground,
      this.showLines = false,
      this.lineColor,
      this.indent = 16,
      this.originalNodeItemBuilder,
      this.willRecorder,
      this.onReorder})
      : super(key: key);

  ///If [scrollable] is true. The [nodeWidth] will match parent width.
  final double nodeWidth;

  /// support horizontal scroll
  final bool scrollable;

  final List<TreeNode<T>> nodes;

  /// Node item widget.
  final NodeItemBuilder<T>? nodeItemBuilder;

  final NodeItemBackground<T>? nodeItemBackground;

  /// Show the lines of parent -> child.
  final bool showLines;

  final Color? lineColor;

  /// Replace [RecommendNodeWidget]
  final NodeItemBuilder<T>? originalNodeItemBuilder;

  final double indent;

  /// Todo: support reorder in different nodes.
  final WillReorder<T>? willRecorder;

  /// Todo: support reorder in different nodes.
  final OnReorder<T>? onReorder;

  @override
  _FlexibleTreeViewState createState() => _FlexibleTreeViewState<T>();
}

class _FlexibleTreeViewState<T> extends State<FlexibleTreeView<T>>
    implements TreeObserver {
  final List<TreeNode<T>> _listShowNodes = [];
  final _horizontalScrollController = ScrollController();

  //Max depth is to dynamic evaluate the tree width.
  int _maxDepth = 0;

  @override
  void initState() {
    _updateShowNodes();
    super.initState();
  }

  @override
  void didUpdateWidget(FlexibleTreeView<T> oldWidget) {
    _updateShowNodes();
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void rebuild() {
    setState(() {
      _updateShowNodes();
    });
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

    if (source.hasNodes && source.expanded) {
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
    return widget.scrollable
        ? Scrollbar(
            controller: _horizontalScrollController,
            trackVisibility: true,
            child: SingleChildScrollView(
              controller: _horizontalScrollController,
              scrollDirection: Axis.horizontal,
              child: _buildTreeList(),
            ),
          )
        : _buildTreeList();
  }

  Widget _buildTreeList() => Material(
        color: Colors.transparent,
        child: Container(
          width: widget.scrollable
              ? (_maxDepth * widget.indent + widget.nodeWidth)
              : double.infinity,
          alignment: Alignment.centerLeft,
          child: ReorderableListViewEx.builder(
            scrollController: ScrollController(),
            isItemReorderable: (index) {
              var node = _listShowNodes[index];
              // log('Item reorderable: ${node.reorderable}');
              return node.reorderable;
            },
            onReorder: (oldIndex, newIndex) {
              var orderNode = _listShowNodes[oldIndex];
              var orderUpper = false;
              if (oldIndex < newIndex) {
                newIndex -= 1;
                orderUpper = true;
              }
              var currentNode = _listShowNodes[newIndex];
              var canReorder =
                  widget.willRecorder?.call(orderNode, currentNode) ?? false;
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
                      orderNode._removeSelf();
                    } else if (widget.nodes.contains(orderNode)) {
                      widget.nodes.remove(orderNode);
                    }

                    var children = currentNode.parent!.children;
                    var index = children.indexOf(currentNode);
                    if (orderUpper) {
                      currentNode.parent!._insertNodeAt(index + 1, orderNode);
                    } else {
                      currentNode.parent!._insertNodeAt(index, orderNode);
                    }
                    rebuild();
                  } else if (widget.nodes.contains(currentNode)) {
                    if (orderNode.parent != null) {
                      orderNode._removeSelf();
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
            itemCount: _listShowNodes.length,
            itemBuilder: (context, index) {
              var node = _listShowNodes[index];
              return TreeNodeWidget<T>(
                key: GlobalObjectKey(node.key),
                node: node,
                builder: (context, node) => widget.originalNodeItemBuilder !=
                        null
                    ? DecoratedBox(
                        decoration: BoxDecoration(
                          color: widget.nodeItemBackground?.call(context, node),
                        ),
                        child: widget.originalNodeItemBuilder!(context, node),
                      )
                    : RecommendNodeWidget<T>(
                        node: node,
                        builder: widget.nodeItemBuilder,
                        backgroundBuilder: widget.nodeItemBackground,
                        showLines: widget.showLines,
                        lineColor: widget.lineColor,
                        nodeWidth: widget.scrollable
                            ? widget.nodeWidth
                            : double.infinity,
                        indent: widget.indent,
                      ),
              );
            },
          ),
        ),
      );
}

class TreeNodeWidget<T> extends StatefulWidget {
  const TreeNodeWidget({
    Key? key,
    required this.node,
    required this.builder,
  }) : super(key: key);

  final TreeNode<T> node;
  final NodeItemBuilder<T> builder;

  @override
  _TreeNodeWidgetState<T> createState() => _TreeNodeWidgetState<T>();
}

class _TreeNodeWidgetState<T> extends State<TreeNodeWidget<T>>
    with SingleTickerProviderStateMixin {
  @override
  void initState() {
    widget.node.addListener(_onNodeChanged);

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, widget.node);
  }

  void _onNodeChanged() {
    setState(() {});
  }
}

class RecommendNodeWidget<T> extends StatelessWidget {
  const RecommendNodeWidget({
    Key? key,
    required this.node,
    this.builder,
    this.backgroundBuilder,
    this.nodeWidth,
    this.showLines = false,
    this.lineColor,
    this.indent = 16.0,
  }) : super(key: key);

  final TreeNode<T> node;
  final NodeItemBuilder<T>? builder;
  final NodeItemBackground<T>? backgroundBuilder;
  final double? nodeWidth;
  final bool showLines;
  final Color? lineColor;
  final double indent;

  @override
  Widget build(BuildContext context) {
    var verticalLines = <Widget>[];
    var parent = node.parent;
    while (showLines && parent != null) {
      //Only draw line when the children > 1
      if (parent.children.length > 1) {
        verticalLines.add(
          Positioned(
            top: 0,
            bottom: 0,
            left: parent.depth * indent,
            child: VerticalDivider(
              color: lineColor ?? Colors.black54,
              width: 1,
            ),
          ),
        );
      }
      parent = parent.parent;
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundBuilder?.call(context, node),
      ),
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(left: node.depth * indent),
            child: SizedBox(
              width: nodeWidth,
              child: builder?.call(context, node),
            ),
          ),
          if (showLines &&
              node.depth > 0 &&
              ((node.parent?.children.length ?? 0) > 1))
            Positioned(
              top: 0,
              bottom: 0,
              left: (node.depth - 1) * indent,
              width: indent,
              child: Divider(
                color: lineColor ?? Colors.black54,
                thickness: 1,
              ),
            ),
          ...verticalLines
        ],
      ),
    );
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
        key = key ?? data.hashCode.toString() {
    if (parent != null) {
      _parent = parent;
      _depth = parent._depth + 1;
    }
    if (expanded != null) {
      _expanded = expanded;
    }
    if (children != null) {
      children.forEach((element) {
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

  bool get hasNodes => _children?.isNotEmpty == true;

  int nodeIndexAt(TreeNode<T> node) => _children?.indexOf(node) ?? -1;

  void addNode(TreeNode<T> node) {
    _addNode(node);
    _treeObserver?.rebuild();
  }

  void _addNode(TreeNode<T> node) {
    node.parent = this;
    children.add(node);
  }

  void insertNodeAt(int index, TreeNode<T> node) {
    _insertNodeAt(index, node);
    _treeObserver?.rebuild();
  }

  void _insertNodeAt(int index, TreeNode<T> node) {
    node.parent = this;
    children.insert(index, node);
  }

  void addNodes(List<TreeNode<T>> nodes) {
    _addNodes(nodes);
    _treeObserver?.rebuild();
  }

  void _addNodes(List<TreeNode<T>> nodes) {
    nodes.forEach((element) {
      element.parent = this;
    });
    children.addAll(nodes);
  }

  void clearNodes() {
    _clearNodes();
    _treeObserver?.rebuild();
  }

  void _clearNodes() {
    _children?.forEach((element) {
      element.parent = null;
    });
    _children?.clear();
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

  void removeNodes(List<TreeNode<T>> nodes) {
    _removeNodes(nodes);
    _treeObserver?.rebuild();
  }

  void _removeNodes(List<TreeNode<T>> nodes) {
    nodes.forEach((element) {
      if (children.contains(element)) {
        element.parent = null;
        children.remove(element);
      }
    });
  }

  void removeNodeAt(int index) {
    _removeNodeAt(index);
    _treeObserver?.rebuild();
  }

  void _removeNodeAt(int index) {
    if (index < children.length) {
      children[index].parent = null;
      children.removeAt(index);
    }
  }

  void removeRange(int start, int end) {
    _removeRange(start, end);
    _treeObserver?.rebuild();
  }

  void _removeRange(int start, int end) {
    assert(start >= 0 && start <= end && end < children.length);
    for (var i = 0; i < children.length; i++) {
      if (i >= start && i <= end) {
        children[i].parent = null;
      }
    }
    children.removeRange(start, end);
  }

  void removeWhere(bool Function(TreeNode<T>) where) {
    _removeWhere(where);
    _treeObserver?.rebuild();
  }

  void _removeWhere(bool Function(TreeNode<T>) where) {
    _children?.removeWhere((node) {
      var test = where(node);
      if (test) {
        node.parent = null;
      }
      return test;
    });
  }

  void removeSelf() {
    _removeSelf();
    notifyDataChanged();
  }

  void _removeSelf() {
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
