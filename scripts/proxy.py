#!/usr/bin/env python3
import traceback
import random
import socket
import argparse
import threading
import signal
from contextlib import contextmanager

running = True

CLIENT2SERVER = 1
SERVER2CLIENT = 2

c2s = 0
s2c = 0

@contextmanager
def ignored(*exceptions):
  try:
    yield
  except exceptions:
    pass 

def killp(a, b):
  with ignored(Exception):
    a.shutdown(socket.SHUT_RDWR)
    a.close()
    b.shutdown(socket.SHUT_RDWR)
    b.close()
  return

def worker(client, server, direction):
  global c2s
  global s2c

  while running == True: # and not is_socket_closed(client) and not is_socket_closed(server):
    b = ""
    with ignored(Exception):
      b = client.recv(1024)
    if len(b) == 0:
      killp(client,server)
      return
    # print("Intercepted bytes: ", len(b))
    try:
      if direction == CLIENT2SERVER:
        c2s += len(b)
      elif direction == SERVER2CLIENT:
        s2c += len(b)
    except:
      pass
    try:
      server.send(b)
    except:
      killp(client,server)
      return
  killp(client,server)
  return

def signalhandler(sn, sf):
  # print("*** signalhandler ***")
  running = False

def inthandler(sn, sf):
  global c2s
  global s2c
  # print("*** inthandler ***")

  print("Client to server (bytes): ", c2s)
  print("Server to client (bytes): ", s2c)
  print("Total (bytes): ", (c2s + s2c), flush=True)
  sys.stdout.flush()
  exit()

def doProxyMain(port, remotehost, remoteport):
  signal.signal(signal.SIGTERM, signalhandler)
  signal.signal(signal.SIGINT, inthandler)
  try:
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    s.bind(("0.0.0.0", port))
    s.listen(1)
    workers = []
    print("Starting proxy on: ", port)
    while running == True:
      k,a = s.accept()
      v = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
      v.connect((remotehost, remoteport))
      t1 = threading.Thread(target=worker, args=(k,v,CLIENT2SERVER))
      t2 = threading.Thread(target=worker, args=(v,k,SERVER2CLIENT))
      t2.start()
      t1.start()
      workers.append((t1,t2,k,v))
  except Exception:
    signalhandler(None, None)
  for t1,t2,k,v in workers:
    killp(k,v)
    t1.join()
    t2.join()
  return

# # https://stackoverflow.com/a/62277798
# def is_socket_closed(sock):
#     try:
#         # this will try to read bytes without blocking and also without removing them from buffer (peek only)
#         data = sock.recv(16, socket.MSG_DONTWAIT | socket.MSG_PEEK)
#         if len(data) == 0:
#             return True
#     except BlockingIOError:
#         return False  # socket is open and reading from it would block
#     except ConnectionResetError:
#         return True  # socket was closed for some other reason
#     except Exception as e:
#         # logger.exception("unexpected exception when checking if a socket is closed")
#         return False
#     return False

if __name__ == '__main__':
  parser = argparse.ArgumentParser(description='Proxy')
  parser.add_argument('-p', type=int, default=8080, help="listen port")
  parser.add_argument('-s', type=str, default="127.0.0.1", help="server ip address")
  parser.add_argument('-q', type=int, default=8081, help="server port")
  args = parser.parse_args()
  doProxyMain(args.p, args.s, args.q)
