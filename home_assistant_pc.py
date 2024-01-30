# script qui exporte le résultat de la commande sensors vers home assistant à travers MQTT
#
# apt-get install lm-sensors
# pip install paho-mqtt


# Config

mosquitto_host="192.168.1.60"
HAPrefix="homeassistant"


import subprocess, json, re, time
from paho.mqtt import client as mqtt_client
import hashlib, base64

hname=subprocess.check_output("hostname", shell=True).decode('utf-8').strip()
chname = hname.replace("-", "_")
output = subprocess.check_output("sensors -j", shell=True)
j=json.loads(output)

json_device = {
    "identifiers":["PC-"+hname],
    "manufacturer": "cc747",
    "model":"cc747",
    "name":hname }

state_topic=HAPrefix+"/sensor/"+chname+"/statePy"
print(state_topic)

client = mqtt_client.Client(hname)
#client.on_connect = on_connect
client.connect(mosquitto_host)
client.loop_start()

def HandleComponent(k, k2, value, device_class, unit):
    d=hashlib.md5( (k2 + k).encode("utf-8"))
    h=re.sub('[^0-9A-Za-z]', '', base64.b64encode(d.digest()).decode("ascii"))
    j = {
        "name":k + " " + k2,
        "uniq_id":chname+h,
        "object_id":chname,
        "expire_after":1200,
        "device_class":device_class,
        "val_tpl":"{{value_json['"+k+"']['"+k2+"']}}",
        "unit_of_meas":unit,
        "state_topic":state_topic,
        "device":json_device}
    client.publish(HAPrefix + "/sensor/"+chname+"_"+h+"/config", json.dumps(j, indent=4))
    print(device_class+" "+h)
    client.loop(timeout=1, max_packets=1)

json_out = dict()
for subcomponent in j.keys():
    for k in j[subcomponent].keys():
        if isinstance(j[subcomponent][k], dict):
            json_out[k] = dict()
            for k2 in j[subcomponent][k].keys():
                if re.match("temp.*_input", k2):
                    json_out[k][k2] = j[subcomponent][k][k2]
                    HandleComponent(k, k2, j[subcomponent][k][k2], "temperature", "°C")
                if re.match("fan.*_input", k2):
                    json_out[k][k2] = j[subcomponent][k][k2]
                    HandleComponent(k, k2, j[subcomponent][k][k2], "speed", "RPM")

client.publish(state_topic, json.dumps(json_out, indent=4))
print(json.dumps(json_out, indent=4))

client.loop(timeout=10, max_packets=10)
