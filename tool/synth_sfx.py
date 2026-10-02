import numpy as np, wave, math
SR = 44100
rng = np.random.default_rng(7)

def biquad(x, kind, f, q=0.707):
    w = 2*math.pi*f/SR; a = math.sin(w)/(2*q); c = math.cos(w)
    if kind == 'lp': b=[(1-c)/2,1-c,(1-c)/2]
    elif kind == 'hp': b=[(1+c)/2,-(1+c),(1+c)/2]
    else: b=[a,0,-a]  # bandpass
    A=[1+a,-2*c,1-a]
    b=[v/A[0] for v in b]; A=[v/A[0] for v in A]
    y=np.zeros_like(x); x1=x2=y1=y2=0.0
    for i,v in enumerate(x):
        o=b[0]*v+b[1]*x1+b[2]*x2-A[1]*y1-A[2]*y2
        x2,x1=x1,v; y2,y1=y1,o; y[i]=o
    return y

def env(n, attack, tau):
    t=np.arange(n)/SR
    e=np.exp(-t/tau)
    a=int(attack*SR)
    if a>0: e[:a]*=np.linspace(0,1,a)
    return e

def save(name, x, peak=0.9):
    x = x/np.max(np.abs(x))*peak
    # Мягкий хвост в ноль — без щелчка в конце.
    f=int(0.004*SR); x[-f:]*=np.linspace(1,0,f)
    d=(x*32767).astype(np.int16)
    with wave.open(name,'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(d.tobytes())
    spec=np.abs(np.fft.rfft(x)); fr=np.fft.rfftfreq(len(x),1/SR)
    print(name, f'{len(x)/SR*1000:.0f} мс', 'центр спектра', int((spec*fr).sum()/spec.sum()), 'Гц')

# Шлепок: сухой хлопок резиной по цели — короткий шум в середине частот
# и совсем лёгкий «тук» снизу. Без длинного хвоста — не гулкий.
def slap(seed, bright):
    r=np.random.default_rng(seed)
    n=int(0.075*SR)
    noise=r.standard_normal(n)
    crack=biquad(biquad(noise,'hp',900),'lp',bright)*env(n,0.0008,0.012)
    t=np.arange(n)/SR
    f0=170+20*seed
    thump=np.sin(2*math.pi*f0*t*(1-t*3))*env(n,0.001,0.010)*0.35
    return crack+thump

for i,(s,b) in enumerate([(1,5200),(2,4600),(3,5800)],1):
    save(f'hit{i}.wav', slap(s,b))

# Хруст жука: серия мелких сухих щелчков (панцирь) за ~60 мс,
# высокий шум, тона нет — не похоже на мячик.
def crunch(seed):
    r=np.random.default_rng(seed)
    n=int(0.09*SR)
    x=np.zeros(n)
    times=np.sort(r.uniform(0,0.055,9)); times[0]=0
    for k,tm in enumerate(times):
        i=int(tm*SR); m=int(0.012*SR)
        g=r.standard_normal(m)*env(m,0.0003,0.0025)*(1.0-0.07*k)*r.uniform(0.6,1)
        x[i:i+m]+=g[:n-i]
    x=biquad(biquad(x,'hp',1800),'lp',9000)
    body=biquad(r.standard_normal(n),'bp',700,1.2)*env(n,0.001,0.018)*0.5
    return x+body

for i,s in enumerate([11,12,13],1):
    save(f'kill{i}.wav', crunch(s), peak=0.85)
