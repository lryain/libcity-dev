extends Node


const node_disable_signal_name : StringName = &"pool_free"

var nodeScene : PackedScene

#Stores projectiles that can be re-used
var disabled := []


func initialize(nodeScene : PackedScene, amount : int):
	self.nodeScene = nodeScene

	#Reset the pooler if it already has children
	reset_pooler()


	for i in range(amount):
		var node_inst := nodeScene.instantiate()
		disable_node(node_inst)
		disabled.push_back(node_inst)
		node_inst.connect(node_disable_signal_name, on_pool_free)
		add_child(node_inst)



func spawn_projectile() -> Node:
	var node : Node = disabled.pop_back()

	if(node == null):
		node = nodeScene.instantiate()
		node.connect(node_disable_signal_name, on_pool_free)
		add_child(node)
		return node

	enable_node(node)
	node.on_start()

	print("Left in Pool = " + str(disabled.size()))

	print(node)
	return node



func on_pool_free(node : Node):
	disable_node(node)
	disabled.push_back(node)



func disable_node(node : Node):
	node.visible = false
	node.set_process(false)
	node.set_physics_process(false)

	if node is CollisionObject3D:
		node.process_mode = Node.PROCESS_MODE_DISABLED
		node.disable_mode = CollisionObject3D.DISABLE_MODE_REMOVE


func enable_node(node : Node):
	node.visible = true
	node.set_process(true)
	node.set_physics_process(true)

	if node is CollisionObject3D:
		node.process_mode = Node.PROCESS_MODE_INHERIT
		node.disable_mode = CollisionObject3D.DISABLE_MODE_KEEP_ACTIVE


func reset_pooler():
	for child in get_children():
		child.queue_free()




