cat <<. | nc $1 8080
POST / HTTP/1.0

{
	"action": "set",
	"color": {
		"r": $2,
		"g": $3,
		"b": $4 
	}
}
.
