extends CharacterBody2D

@export var move_speed: float = 100
@export var starting_direction : Vector2 = Vector2(0, 1)
@export var hp = 80;
var maxhp = 80
var time = 0
@onready var animation_tree = $AnimationTree
@onready var state_machine = animation_tree.get("parameters/playback")
var last_movement = Vector2.UP;

#EXP
var experience = 0
var experience_level = 1
var collected_experience = 0;

#UPGRADES
var collected_upgrades = []
var upgrade_options = []
var armor = 0
var speed = 0
var spell_cooldown = 0
var spell_size = 0
var additional_attacks = 0


#Attacks
var carrot = preload("res://Characters/Attack/carrot.tscn");
var tornado = preload("res://Characters/Attack/tornado.tscn");
var javelin = preload("res://Characters/Attack/javalin.tscn");

#AttackNodes
@onready var carrotTimer = get_node("%CarrotTimer");
@onready var carrotAttackTimer = get_node("%CarrotAttackTimer");
@onready var tornadoTimer = get_node("%TornadoTimer");
@onready var tornadoAttackTimer = get_node("%TornadoAttackTimer");
@onready var javelinBase = get_node("%javelinBase")
#Carrot

var carrot_ammo = 0;
var carrot_base_ammo = 0;
var carrot_attackspeed = 1.5;
var carrot_level = 0;

#Tornado

var tornado_ammo = 0;
var tornado_base_ammo = 0;
var tornado_attackspeed = 3;
var tornado_level = 0;

#javelin

var javelin_ammo = 0;
var javelin_level = 0;

#Enemy Related
var enemy_close = [];

#GUI
@onready var expBar = get_node("%ExperienceBar")
@onready var lblLevel = get_node("%lbl_level")
@onready var levelPanel = get_node("%Levelup")
@onready var upgradeOptions = get_node("%UpgradeOptions")
@onready var sndLevelUp = get_node("%snd_levelup")
@onready var itemOptions = preload("res://Utility/item_option.tscn")
@onready var healthBar = get_node("%HealthBar")
@onready var lblTimer = get_node("%lblTimer")
@onready var collectedWeapons = get_node("%CollectedWeapons")
@onready var collectedUpgrades = get_node("%CollectedUpgrades")
@onready var itemContainer = preload("res://Characters/GUI/item_container.tscn")
@onready var deathPanel = get_node("%DeathPanel");
@onready var lblresult = get_node("%lbl_result")


func _ready():
	upgrade_character("carrot1")
	_update_animation_parameters(starting_direction)
	attack()
	set_expbar(experience, calculate_experiencecap())
	_on_hurtbox_hurt(0,0,0)


func _physics_process(delta):
	var input_Direction = Vector2(Input.get_action_strength("right") - Input.get_action_strength("left"), 
	Input.get_action_strength("down") - Input.get_action_strength("up")
	)
	_update_animation_parameters(input_Direction)
	last_movement = input_Direction;
	velocity = input_Direction * move_speed
	
	move_and_slide()
	pick_new_state()
func _update_animation_parameters(move_input: Vector2):
	if(move_input != Vector2.ZERO):
		animation_tree.set("parameters/Walk/blend_position", move_input)
		animation_tree.set("parameters/Idle/blend_position", move_input)

func pick_new_state():
	if(velocity != Vector2.ZERO):
		state_machine.travel("Walk")
	else:
		state_machine.travel("Idle")

func attack():
	if carrot_level > 0:
		carrotTimer.wait_time = carrot_attackspeed * (1-spell_cooldown);
		if carrotTimer.is_stopped():
			carrotTimer.start();
	if tornado_level > 0:
		tornadoTimer.wait_time = tornado_attackspeed * (1-spell_cooldown);
		if tornadoTimer.is_stopped():
			tornadoTimer.start();
	if javelin_level > 0:
		spawn_javelin()

func _on_hurtbox_hurt(damage, _angle, _knockback):
	hp -= clamp(damage-armor, 1.0, 999.0)
	healthBar.max_value = maxhp
	healthBar.value = hp
	if hp <= 0:
		death()


func _on_carrot_timer_timeout():
	carrot_ammo += carrot_base_ammo + additional_attacks;
	carrotAttackTimer.start();


func _on_carrot_attack_timer_timeout():
	if carrot_ammo > 0:
		var carrot_attack = carrot.instantiate();
		carrot_attack.position = position;
		carrot_attack.target = get_random_target();
		carrot_attack.level = carrot_level;
		add_child(carrot_attack);
		carrot_ammo -= 1;
		if carrot_ammo > 0:
			carrotAttackTimer.start();
		else:
			carrotAttackTimer.stop();
			
func _on_tornado_timer_timeout():
	tornado_ammo += tornado_base_ammo + additional_attacks;
	tornadoAttackTimer.start();


func _on_tornado_attack_timer_timeout():
	if tornado_ammo > 0:
		var tornado_attack = tornado.instantiate();
		tornado_attack.position = position;
		tornado_attack.last_movement = last_movement;
		tornado_attack.level = tornado_level;
		add_child(tornado_attack);
		tornado_ammo -= 1;
		if tornado_ammo > 0:
			tornadoAttackTimer.start();
		else:
			tornadoAttackTimer.stop();
			

func spawn_javelin():
	var get_javelin_total = javelinBase.get_child_count()
	var calc_spawn = (javelin_ammo + additional_attacks) - get_javelin_total;
	while calc_spawn > 0:
		var javelin_spawn = javelin.instantiate();
		javelin_spawn.global_position = global_position;
		javelinBase.add_child(javelin_spawn);
		calc_spawn -= 1;
	var get_javelins = javelinBase.get_children()
	for i in get_javelins:
		if i.has_method("update_javelin"):
			i.update_javelin()

func get_random_target():
	if enemy_close.size() > 0:
		return enemy_close.pick_random().global_position;
	else:
		return Vector2.UP;


func _on_enemy_detection_area_body_entered(body):
	if not enemy_close.has(body):
		enemy_close.append(body);


func _on_enemy_detection_area_body_exited(body):
		if enemy_close.has(body):
			enemy_close.erase(body);


func _on_grab_area_area_entered(area):
	if area.is_in_group("loot"):
		area.target = self


func _on_collect_area_area_entered(area):
	if area.is_in_group("loot"):
		var gem_exp = area.collect()
		calculate_experience(gem_exp)
		
func calculate_experience(gem_exp):
	var exp_required = calculate_experiencecap()
	collected_experience += gem_exp
	if experience + collected_experience >= exp_required: #level up
		collected_experience -= exp_required-experience
		experience_level += 1
		experience = 0
		exp_required = calculate_experiencecap()
		lblLevel.text = str("Level: ",experience_level)
		levelup()
		calculate_experience(0);
	else:
		experience += collected_experience
		collected_experience = 0
	set_expbar(experience, exp_required)

func calculate_experiencecap():
	var exp_cap = experience_level
	if experience_level < 20:
		exp_cap = experience_level*5
	elif experience_level < 40:
		exp_cap + 95 * (experience_level-19)*8
	else:
		exp_cap = 255 + (experience_level-39)*12
		
	return exp_cap
	
func set_expbar(set_value = 1, set_max_value = 100):
	expBar.value = set_value
	expBar.max_value = set_max_value	

func levelup():
	#sndLevelUp.play()
	lblLevel.text = str("Level: ",experience_level)
	var tween = levelPanel.create_tween()
	tween.tween_property(levelPanel,"position",Vector2(90,23),.2).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	tween.play()
	levelPanel.visible = true
	var options = 0
	var optionsmax = 3
	while options < optionsmax:
		var option_choice = itemOptions.instantiate()
		option_choice.item = get_random_item();
		upgradeOptions.add_child(option_choice)
		options += 1
	get_tree().paused = true
	
	
func upgrade_character(upgrade):
	match upgrade:
		"carrot1":
			carrot_level = 1
			carrot_base_ammo += 1
		"carrot2":
			carrot_level = 2
			carrot_base_ammo += 1
		"carrot3":
			carrot_level = 3
		"carrot4":
			carrot_level = 4
			carrot_base_ammo += 2
		"tornado1":
			tornado_level = 1
			tornado_base_ammo += 1
		"tornado2":
			tornado_level = 2
			tornado_base_ammo += 1
		"tornado3":
			tornado_level = 3
			tornado_attackspeed -= 0.5
		"tornado4":
			tornado_level = 4
			tornado_base_ammo += 1
		"javelin1":
			javelin_level = 1
			javelin_ammo = 1
		"javelin2":
			javelin_level = 2
		"javelin3":
			javelin_level = 3
		"javelin4":
			javelin_level = 4
		"armor1","armor2","armor3","armor4":
			armor += 1
		"speed1","speed2","speed3","speed4":
			move_speed += 20.0
		"tome1","tome2","tome3","tome4":
			spell_size += 0.10
		"scroll1","scroll2","scroll3","scroll4":
			spell_cooldown += 0.05
		"ring1","ring2":
			additional_attacks += 1
		"food":
			hp += 20
			hp = clamp(hp,0,maxhp)
	adjust_gui_collection(upgrade)
	attack()
	var option_children = upgradeOptions.get_children()
	for i in option_children:
		i.queue_free()
	upgrade_options.clear()
	collected_upgrades.append(upgrade)
	levelPanel.visible = false
	levelPanel.position = Vector2(800,50)
	get_tree().paused = false
	calculate_experience(0)
	

func get_random_item():
	var dblist = []
	for i in UpgradeDb.UPGRADES:
		if i in collected_upgrades: #Find already collected upgrades
			pass
		elif i in upgrade_options: #If the upgrade is already an option
			pass
		elif UpgradeDb.UPGRADES[i]["type"] == "item": #Don't pick food
			pass
		elif UpgradeDb.UPGRADES[i]["prerequisite"].size() > 0: #Check for PreRequisites
			var to_add = true
			for n in UpgradeDb.UPGRADES[i]["prerequisite"]:
				if not n in collected_upgrades:
					to_add = false
			if to_add:
				dblist.append(i)
		else:
			dblist.append(i)
	if dblist.size() > 0:
		var randomitem = dblist.pick_random()
		upgrade_options.append(randomitem)
		return randomitem
	else:
		return null

func change_time(argtime = 0):
	time = argtime
	var get_m = int(time/60.0)
	var get_s = time % 60
	if get_m < 10:
		get_m = str(0,get_m)
	if get_s < 10:
		get_s = str(0,get_s)
	lblTimer.text = str(get_m,":",get_s)
	
func adjust_gui_collection(upgrade):
	var get_upgraded_displayname = UpgradeDb.UPGRADES[upgrade]["displayname"]
	var get_type = UpgradeDb.UPGRADES[upgrade]["type"]
	if get_type != "item":
		var get_collected_displaynames = []
		for i in collected_upgrades:
			get_collected_displaynames.append(UpgradeDb.UPGRADES[i]["displayname"])
		if not get_upgraded_displayname in get_collected_displaynames:
			var new_item = itemContainer.instantiate()
			new_item.upgrade = upgrade
			match get_type:
				"weapon":
					collectedWeapons.add_child(new_item)
				"upgrade":
					collectedUpgrades.add_child(new_item)

func death():
	deathPanel.visible = true
	emit_signal("playerdeath")
	get_tree().paused = true
	var tween = deathPanel.create_tween()
	tween.tween_property(deathPanel,"position",Vector2(90,23),.2).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	tween.play()
	if time >= 300:
		lblresult.text = "You Win"
	else:
		lblresult.text = "You Lose"
