"""A WebKit speculative connection must not block another website-data store."""
import socket, subprocess, sys, time
from pathlib import Path
from urllib.request import urlopen
with socket.socket() as reservation:
    reservation.bind(('127.0.0.1',0));port=reservation.getsockname()[1]
server=subprocess.Popen([sys.executable,str(Path(__file__).with_name('fixture.py')),str(port)],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
try:
    for attempt in range(50):
        try:
            with urlopen(f'http://127.0.0.1:{port}/a',timeout=1) as response:
                assert b'Lookout Fixture A' in response.read()
            break
        except OSError:
            if attempt==49:raise
            time.sleep(.02)
    with socket.create_connection(('127.0.0.1',port),timeout=2) as speculative:
        # Leave the first socket open without an HTTP request, as WebKit may do.
        with urlopen(f'http://127.0.0.1:{port}/b',timeout=2) as response:
            assert b'Lookout Fixture B' in response.read()
    print('Fixture serves private and regular WebKit connections independently.')
finally:
    server.terminate();server.wait(timeout=5)
