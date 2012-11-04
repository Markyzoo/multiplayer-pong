exports = exports ? this

exports.WebPongJSConfig =
  server:
    addr: '0.0.0.0',
    port: 8089,
    prefix: '/pong',
  update:
    # milliseconds
    interval: 30,   # Game update intervals, ms.
    syncTime: 200,  # Server sync period
    maxDrift: 200,  # Maximum drift for each client
  board:
    id: 'board'
    size:
      x: 600, y: 400
  block:
    size:
      x: 50, y: 100
    left: color: 'blue'
    right: color: 'red'
  ball:
    radius: 10
    xVelocity: 0.2
    yVelocity: 0.4
    color: 'black'
