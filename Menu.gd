extends Control

var level = "res://Levels/game_level.tscn"

func _on_button_play_button_up():
	var _level = get_tree().change_scene_to_file(level)


func _on_button_exit_button_up():
	get_tree().quit()
