{
  "id": "/withinboredom/consul-template",
  "args": [
    "consul", "${HOST}",
    "template", "stuff:more-stuff"
  ],
  "container": {
    "type": "DOCKER",
    "docker": {
      "image": "withinboredom/docker-consul-template",
      "network": "HOST"
    },
    "volumes": [
      {
        "containerPath": "/tmp/docker.sock",
        "hostPath": "/var/run/docker.sock",
        "mode": "RW"
      }
    ]
  },
  "cpus": 0.1,
  "mem": 25,
  "instances": ${INSTANCES},
  "constraints": [
    ["slave_type", "CLUSTER", "master"],
    ["hostname", "UNIQUE"]
  ],
  "dependencies": [
    "/withinboredom/registrator"
  ]
}