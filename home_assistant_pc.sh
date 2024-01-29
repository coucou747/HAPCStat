# Script qui permet d'enovyer l'uptime et l'occupation des disques durs à home assistant à travers MQTT.

hname=`hostname`
mosquitto_host="192.168.1.60"
HAPrefix="homeassistant"

chname=${hname/-/_}
echo "Home assistant MQTT messages for $chname"
IFS='' read -r -d '' json_device <<EOF
  {
    "identifiers":["PC-$hname"],
    "manufacturer": "cc747",
    "model":"cc747",
    "name":"$hname"
  }
EOF

state_topic="$HAPrefix/sensor/$chname/state"

function harddriveLine () {
    if [ "M" == "${2: -1}" ]; then
	used="0G"
    else
	used="$2"
    fi
    disksmallname=${1//\//}
    IFS='' read -r -d '' json <<EOF
{
  "name":"$1 total",
  "uniq_id":"${chname}${disksmallname}_total",
  "object_id":"$chname",
  "expire_after":120,
  "device_class":"data_size",
  "val_tpl":"{{value_json['${disksmallname}total']}}",
  "unit_of_meas":"GB",
  "state_topic":"$state_topic",
  "device":$json_device}
EOF
   mosquitto_pub -r -h "$mosquitto_host" -t "$HAPrefix/sensor/${chname}${disksmallname}_total/config" -m "$json"
   IFS='' read -r -d '' json <<EOF
{
  "name":"$1 used",
  "uniq_id":"${chname}${disksmallname}_used",
  "object_id":"$chname",
  "expire_after":120,
  "device_class":"data_size",
  "val_tpl":"{{value_json['${disksmallname}used']}}",
  "unit_of_meas":"GB",
  "state_topic":"$state_topic",
  "device":$json_device}
EOF
  mosquitto_pub -r -h "$mosquitto_host" -t "$HAPrefix/sensor/${chname}${disksmallname}_used/config" -m "$json"
   IFS='' read -r -d '' json <<EOF
{
  "name":"$1 percent used",
  "uniq_id":"${chname}${disksmallname}_usedP",
  "object_id":"$chname",
  "expire_after":120,
  "device_class":"data_size",
  "val_tpl":"{{value_json['${disksmallname}usedPercent']}}",
  "unit_of_meas":"%",
  "state_topic":"$state_topic",
  "device":$json_device}
EOF
  mosquitto_pub -r -h "$mosquitto_host" -t "$HAPrefix/sensor/${chname}${disksmallname}_used/config" -m "$json"

  echo "  \"${disksmallname}total\":\"${3%?}\","
  echo "  \"${disksmallname}used\":\"${used%?}\","
  echo "  \"${disksmallname}usedPercent\":\"${4%?}\","
}

IFS='' read -r -d '' json <<EOF
{
  "name":"uptime",
  "uniq_id":"${chname}_uptime",
  "object_id":"$chname",
  "device_class":"duration",
  "val_tpl":"{{value_json['uptime']}}",
  "unit_of_meas":"s",
  "state_topic":"$state_topic",
  "device":$json_device
}
EOF
mosquitto_pub -r -h "$mosquitto_host" -t "$HAPrefix/sensor/${hname}_uptime/config" -m "$json"

json_state=""
IFS="
"

for l in `df -lh --output=source,used,size,pcent | grep sd`
do
    IFS=' ' read -r -a array <<< "$l"
    state=$(harddriveLine ${array[0]} ${array[1]} ${array[2]} ${array[3]} )
    json_state="$state$json_state"
done

uptime=`cat /proc/uptime | cut -d ' ' -f 1`
json_state="{
$json_state  \"uptime\":$uptime
}
"

mosquitto_pub -h "$mosquitto_host" -t "$state_topic" -m "$json_state"
