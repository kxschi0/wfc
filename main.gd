extends Node3D

const flooring = preload("res://Assets/floor.tscn")
const road = preload("res://Assets/road.tscn")
const sidewalk = preload("res://Assets/sidewalk_nobevel.tscn")
const crossroad = preload("res://Assets/crossroad.tscn")
const roadstripe = preload("res://Assets/roadstripe.tscn")

var floors = {
	"road": road,
	"floor": flooring,
	"sidewalk": sidewalk,
	"crossroad": crossroad,
	"roadstripe": roadstripe,
}

var wfcrulesN = {
	"road": ["road"],
	"floor": ["floor","sidewalk"],
	"sidewalk": ["sidewalk","roadstripe"],
	"crossroad": ["road"],
	"roadstripe": ["crossroad","roadstripe"],
}
var wfcrulesS = {
	"road": ["crossroad"],
	"floor": ["floor","sidewalk"],
	"sidewalk": ["sidewalk","roadstripe"],
	"crossroad": ["roadstripe"],
	"roadstripe": ["roadstripe","sidewalk"],
}

var wfcrulesW = {
	"road": ["crossroad"],
	"floor": ["floor","sidewalk"],
	"sidewalk": ["sidewalk","roadstripe"],
	"crossroad": ["sidewalk, crossroad"],
	"roadstripe": ["roadstripe","sidewalk"],
}
var wfcrulesE = {
	"road": ["road"],
	"floor": ["floor","sidewalk"],
	"sidewalk": ["sidewalk","roadstripe"],
	"crossroad": ["sidewalk, crossroad"],
	"roadstripe": ["roadstripe","sidewalk"],
}

var gridsize = 3.0

func _ready() -> void:
	pass 

func _process(delta: float) -> void:
	pass
