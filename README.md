![](https://tva1.sinaimg.cn/large/008i3skNgy1gyujo33a5sj30qs0atmxc.jpg)

## Features

- Expand / Collapse the tree nodes;
- Show lines of parent -> child nodes;
- High flexible to custom node widget

## Getting tarted

```yaml
dependencies:
    flexible_tree_view: ^0.0.5
```

## Screen shot

![](https://tva1.sinaimg.cn/large/008i3skNgy1gyui2q97xmj312a0u0jsh.jpg)

![](https://tva1.sinaimg.cn/large/008i3skNgy1gyuilaokvjg30qo0f01j4.gif)

## Usage

```dart
import 'package:flexible_tree_view/flexible_tree_view.dart';

FlexibleTreeView<String>(
	nodes: [
		TreeNode<String>(
			data: 'Cities', 
			expanded: true, 
			children: [
				TreeNode<String>(data: 'Beijing'), 
				TreeNode<String>(data: 'Shanghai'),
				TreeNode<String>(data: 'Tokyo'),
				TreeNode<String>(data: 'Paris')
			]
		)
	],
	nodeItemBuilder: (context, node) {
		return Padding(
			padding: const EdgeInsets.symmetric(vertical: 8),
			child: Row(
				children: [
				node.hasNodes
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
					node.data,
					style: TextStyle(
					fontSize: 12,
					color: Colors.black,
					),
					overflow: TextOverflow.ellipsis,
				)
				],
			));
	},
)
```

# License

See [LICENSE](LICENSE)
