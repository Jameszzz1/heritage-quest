@tool
extends Node

const ENVIRONMENT_VARIABLES : String = "supabase/config"

# Inalis ang explicit types para iwas "Could not find type" error
var auth
var database
var realtime
var storage

var debug: bool = false

# Dito na natin ilagay ang credentials mo para hindi na mag-fail ang URL parsing
var config : Dictionary = {
	"supabaseUrl": "https://jgcjlcbkvcnkdhwxoxhu.supabase.co",
	"supabaseKey": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpnY2psY2JrdmNua2Rod3hveGh1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY4MjE1OTIsImV4cCI6MjA5MjM5NzU5Mn0.JjYp-c0DDSH9-v6gC8wxjtgZH1yc8g0XPER7OnbKBOQ"
}

var header : PackedStringArray = [
	"Content-Type: application/json",
	"Accept: application/json"
]

func _ready() -> void:
	# Load connection only, NO UI LOGIC HERE
	load_config()
	load_nodes()

func load_config() -> void:
	if not header.has("apikey: " + config.supabaseKey):
		header.append("apikey: %s" % [config.supabaseKey])

func load_nodes() -> void:
	# Gumamit ng .new() nang walang type hints para safe
	auth = load("res://addons/supabase/Auth/auth.gd").new(config, header)
	database = load("res://addons/supabase/Database/database.gd").new(config, header)
	realtime = load("res://addons/supabase/Realtime/realtime.gd").new(config)
	storage = load("res://addons/supabase/Storage/storage.gd").new(config)
	add_child(auth)
	add_child(database)
	add_child(realtime)
	add_child(storage)
