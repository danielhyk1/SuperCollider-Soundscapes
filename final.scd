// Day in the life of a average worker

//Sample Buffers
(
~keys = Buffer.read(s, "/keys.wav".resolveRelative);
~sink = Buffer.read(s, "/bathroom_sink.wav".resolveRelative);
~door = Buffer.read(s, "/door_close.wav".resolveRelative);
~city = Buffer.read(s, "/city_noise.wav".resolveRelative);
~beep = Buffer.read(s, "/beep.wav".resolveRelative);
~truck = Buffer.read(s, "/truck.wav".resolveRelative);
~typing = Buffer.read(s, "/typing.wav".resolveRelative);
~convo = Buffer.read(s, "/conversation.wav".resolveRelative);
~gun = Buffer.read(s, "/gun.wav".resolveRelative);

~bedroomIR = Buffer.read(s, "/bedroomIR.wav".resolveRelative);
~cityIR = Buffer.read(s, "/cityIR.wav".resolveRelative);
)

//Impulse Response Buffers
(
~fftsize = 2048;
~bufsize = PartConv.calcBufSize(~fftsize, ~bedroomIR);
~irspectrum1 = Buffer.alloc(s, ~bufsize, 1);
~irspectrum1.preparePartConv(~bedroomIR, ~fftsize);
~bufsize = PartConv.calcBufSize(~fftsize, ~cityIR);
~irspectrum2 = Buffer.alloc(s, ~bufsize, 1);
~irspectrum2.preparePartConv(~cityIR, ~fftsize);
)


//SYNTHDEFS
//Bedroom Alarm

(
SynthDef("bedroom_alarm", {
	var freq, out, operations, env;
	env = EnvGen.kr(Env.perc(20, 50));
	freq = Duty.kr(0.05, 0, Dseq([1000, 1200, 1250], 100), Done.freeSelf); //Frees itself after 100 iterations
	freq = LPF.kr(freq, 70);
	out = SinOsc.ar(freq);
	Out.ar(0, Pan2.ar(out * 0.1 * env));
}).add;

//Bedroom Synth

SynthDef("bedroom_quiet_synth", {arg amp = 1, freq = 440;
	var mod, car, env, indexEnv;
	indexEnv = EnvGen.kr(Env.new([1, 4, 1], [0.01, 3], [4, -4])); // index envelope
	env = EnvGen.kr(Env.perc(0.1, 3), doneAction: Done.freeSelf);
	mod = SinOsc.ar(freq, mul: amp * indexEnv * 0.2);
	car = SinOsc.ar(freq * mod) *env * amp;
	car = Pan2.ar(car, mod);
	Out.ar(0, car);
}).add;

//Bass kick
SynthDef("kick", {
	var sin, env;
    sin = SinOsc.ar(60);
    env = Line.ar(0.5, 0, 1, doneAction: Done.freeSelf);
    Out.ar(0, Pan2.ar(sin*env, 0));
}).add;

//Borrowed Snare Code (https://sccode.org/1-523)
SynthDef("snare", { arg out = 0, pan = 0, amp = 0.3;
    var pop, popAmp, popFreq, noise, noiseAmp, snd;
    popFreq = EnvGen.ar(Env([3261, 410, 160], [0.005, 0.01], curve: \exp));
    popAmp = EnvGen.ar(Env.perc(0.001, 0.11)) * 0.7;
    pop = SinOsc.ar(popFreq) * popAmp;
    // bandpass-filtered white noise
    noiseAmp = EnvGen.ar(Env.perc(0.001, 0.15), doneAction: 2);
    noise = BPF.ar(WhiteNoise.ar, 810, 1.6) * noiseAmp;

    snd = (pop + noise) * 1.3;
    Out.ar(out, Pan2.ar(snd, pan, amp));
}).add;

//Hi hat
SynthDef("hihat", {
	var env, noise;
	env = Env.perc(0.01, 0.1, 0.6).kr(doneAction: Done.freeSelf);
	noise = WhiteNoise.ar;
	noise = HPF.ar(noise, 7777, env);
	Out.ar(0, Pan2.ar(noise, 0));
}).add;

//Car Horn
SynthDef("horn", { arg gate=1, freq=440 ;
	var nos,
	env = Line.ar(2, 1.8, 0.5, doneAction: Done.freeSelf);
	nos = Blip.ar(freq+1)*0.5+Blip.ar(freq/2)*0.5;
	nos = RLPF.ar(nos,SinOsc.kr(0.3, 0, 200, 1000), 0.1);
	nos = FreeVerb.ar(nos, 0.5, 0.5, 0.5);
	Out.ar(0, Pan2.ar(nos * env, 0));
}).add;

//Beep
SynthDef("beep", {
	Out.ar(0, Pan2.ar( PlayBuf.ar(1, ~beep, 1, loop:0)), 0);
}).add;

//convo
SynthDef("convo", {
	var env = Line.ar(2, 1.8, 27, doneAction: Done.freeSelf);
	Out.ar(0, env * 0.67 * Pan2.ar( PlayBuf.ar(1, ~convo, 1, loop:0)), 0);
}).add;


//Typing
SynthDef("typing", { arg amp = 0.6;
	var env, out;
	env = Line.ar(0.2, 1, 4, doneAction: Done.freeSelf);
	out = PlayBuf.ar(1, ~typing, 1, loop:0);
	out = Pan2.ar(out);
	Out.ar(0, out * env * amp);
}).add;


SynthDef("gun", { arg amp = 0.4;
	var env, out;
	env = Line.ar(0.2, 1, 4, doneAction: Done.freeSelf);
	out = PlayBuf.ar(1, ~gun, 1, loop:0);
	out = Pan2.ar(out);
	Out.ar(0, out * env * amp);
}).add;

//Meloncholy Piano
SynthDef(\piano, { arg freq=440, gate=1, amp = 0.1;
    var key = MdaPiano.ar(freq, gate, release: 0.9, stereo: 0.3, sustain: 0, muffle: 0.9, sustain: 0.1, decay: 0.2);
    DetectSilence.ar(key, 0.01, doneAction:2);
	Out.ar(0, Pan2.ar(key * amp, 0));
}).add;

//Cross Synthesis
SynthDef("cross_synth", {arg amp1 = 0.5, amp2 = 0.5, sound1 = ~city, sound2 = ~city, length = 20;
	var mix = Convolution.ar(PlayBuf.ar(1, sound1, loop:1) * amp1, PlayBuf.ar(1, sound2, loop:1) * amp2, 2048);
	var env = EnvGen.kr(Env.perc(0.1, length), doneAction: Done.freeSelf);
	mix = mix * env;
	Out.ar(0, mix ! 2);
}).add;

//Convulusion Reverb
SynthDef("convolution_reverb", {arg irspectrum = ~irspectrum, fftsize = 2048, sound = ~ex, reverb = 0.5;
	var mix = PartConv.ar(PlayBuf.ar(1, sound, 1, loop:0)*reverb, fftsize, irspectrum, 0.5);
	Out.ar(0, mix ! 2);
}).add;
)

//Pbinds
(
~alarm = Pbind(
	\instrument, \bedroom_alarm,
	\midinote, Pseq([60], 1),
	\dur, 10
);

~dream1 = Pbind(
    \instrument, \quiet_bedroom_synth,
	\midinote, Pseq([
		60,64,67,64, 60,64,67,64, 60,64,67,64, 60,64,67,64,
		60,64,67,64, 60,64,67,64, 60,64,67,64, 60,64,67,64,
		55,60,64,60, 55,60,64,60, 55,60,64,60, 55,60,64,60,
		55,60,64,60, 55,60,64,60, 55,60,64,60, 55,60,64,60,
		55,59,62,59, 55,59,62,59, 55,59,62,59, 55,59,62,59,
		55,59,62,59, 55,59,62,59, 55,59,62,59, 55,59,62,59,
	]),
	\amp, 0.35,
	\dur, 0.5,
	\root, 3,
);

~dream2 = Pbind(
	\instrument, \quiet_bedroom_synth,
	\midinote, Pseq([
		60,64,67,72, 74,\,\,\,
		59,64,67,71, 72,\,\,\,
		57,62,65,69, 71,\,\,\,
	], 2),
	\amp, 0.5,
	\dur, 2,
);

~bedroom1 = Pbind(
	\instrument, \quiet_bedroom_synth,
	\midinote, Pseq([
		60,\,\,64, \,60,\,55,
		\,\,\,\, 62,\,\,65,
		\,\,\,\, 62,\,\,59,
		\,\,\,\, 59,\,\,\,
	], 4),
	\amp, 0.5,
	\dur, 1,
);

~bedroom2 = Pbind(
	\instrument, \quiet_bedroom_synth,
	\midinote, Pseq([
		48,\,\,52, \,48,\,43,
		\,\,\,\, 50,\,\,53,
		\,\,\,\, 50,\,\,47,
		\,\,\,\, 47,\,\,\,
	], 4),
	\amp, 0.5,
	\dur, 1,
);

~bedroom3 = Pbind(
	\instrument, \quiet_bedroom_synth,
	\midinote, Pseq([
		72,\,\,\, \,\,\,67,
		\,\,\,\, 74,\,\,\,
		\,\,\,\, 74,\,\,\,
		\,\,\,\, 71,\,\,\,
	], 4),
	\amp, 0.5,
	\dur, 1,
);

~sinkP = Pbind(
	\instrument, \convolution_reverb,
	\sound, ~sink,
	\irspectrum, ~irspectrum1,
	\dur, Pseq([3], 1),
	\reverb, 0.005,
	\delay, 0.05
);


~keysP = Pbind(
	\instrument, \convolution_reverb,
	\sound, ~keys,
	\irspectrum, ~irspectrum1,
	\dur, Pseq([3], 1),
	\reverb, 0.1,
	\delay, 0.1
);

~doorP = Pbind(
	\instrument, \convolution_reverb,
	\sound, ~door,
	\irspectrum, ~irspectrum1,
	\dur, Pseq([3], 1),
	\reverb, 0.01,
	\delay, 0.01
);

~thudP = Pbind(
	\instrument, \cross_synth,
	\sound1, ~door,
	\sound2, ~city,
	\amp1, 0.2,
	\amp2, 0.2,
	\dur, Pseq([1],1)
);

~truckP = Pbind(
	\instrument, \convolution_reverb,
	\sound, ~truck,
	\irspectrum, ~irspectrum2,
	\dur, Pseq([3], 1),
	\reverb, 0.05,
	\delay, 0.03
);


~beepP = Pbind(
	\instrument, \beep,
	\midinote, Pseq([60, 60]),
	\dur, 0.4
);

~cityNoise = ~doorP = Pbind(
	\instrument, \convolution_reverb,
	\sound, ~city,
	\irspectrum, ~irspectrum2,
	\dur, Pseq([3], 1),
	\reverb, 0.01,
	\delay, 0.01
);

~cityKick = Pbind(
	\instrument, \kick,
	\freq, Pseq([
		60,\,\,\, 60,\,\,\,
		60,\,\,\, 60,\,\,\,
		60,\,\,\, 60,\,\,\,
		60,\,\,\, 60,\,\,\,
	], 2),
	\amp, 0.5,
	\dur, 1,
);

~citySnare = Pbind(
	\instrument, \snare,
	\midinote, Pseq([
		\,\,60,\, \,60,\,\,
		\,\,60,\, \,60,\,\,
		\,\,60,\, \,60,\,\,
		\,\,60,\, \,60,\,\,
	], 2),
	\amp, 0.3,
	\dur, 1,
);

~cityHat = Pbind(
	\instrument, \hihat,
	\midinote, Pseq([
		\,60,\,60, \,60,\,60,
		\,60,\,60, \,60,60,60,
		\,60,\,60, \,60,\,60,
		\,60,\,60, \,60,60,60,
	], 2),
	\amp, 0.1,
	\dur, 1,
);

~cityMel1 = Pbind(
	\instrument, \horn,
	\midinote, Pseq([
		72,\,72,\, 72,71,72,71,
		69,\,69,\, 69,71,69,71,
		72,\,72,\, 72,71,72,71,
		69,\,69,\, 69,71,69,71,
	], 2),
	\amp, 0.3,
	\dur, 1,
);

~cityMel2 = Pbind(
	\instrument, \horn,
	\midinote, Pseq([
		72,\,\,\, 67,67,\,\,
		72,\,\,\, 64,64,\,\,
		67,67,\, 64,64,\,\,
		67,\,64,\, 67,\,\,\,

	], 2),
	\amp, 0.3,
	\dur, 1,
);

~officeType = Pbind(
	\instrument, \typing,
	\midinote,Pseq([
		60,60,60,60],4),
	\amp, 0.09,
	\dur, 5,
);

~officeMel0 = Pbind(
	\instrument, \piano,
	\midinote, Pseq([
		84,\,\,\, \,\,\,\,
		84,\,\,\, \,\,\,\,
		84,\,\,\, \,\,\,\,
		84,\,\,\, \,\,\,\,
	]),
	\amp, 0.1,
	\dur, 1,
);

~officeMel1 = Pbind(
	\instrument, \piano,
	\midinote, Pseq([
		84,\,\,\, \,\,\,\,
		83,\,\,\, \,\,\,\,
		81,\,\,\, \,\,\,\,
		79,\,\,\, \,\,\,\,
	], 4),
	\amp, 0.1,
	\dur, 1,
);

~officeMel2 = Pbind(
	\instrument, \piano,
	\midinote, Pseq([
		48,\,52,\, 55,\,\,\,
		47,\,52,\, 55,\,\,\,
		45,\,50,\, 53,\,\,\,
		43,\,47,\, 50,\,\,\,
	], 4),
	\amp, 0.1,
	\dur, 1,
);

~officeMel3 = Pbind(
	\instrument, \piano,
	\midinote, Pseq([
		36,\,40,\, 43,\,\,\,
		35,\,40,\, 43,\,\,\,
		33,\,38,\, 41,\,\,\,
		31,\,35,\, 38,\,\,\,
	], 4),
	\amp, 0.1,
	\dur, 1,
);

~convoP = Pbind(
	\instrument, \convo,
	\midinote, Pseq([60], 1),
	\dur, 0.5
);

~gunP = Pbind(
	\instrument, \gun,
	\midinote, Pseq([60], 1),
	\dur, 0.5,
	\amp, 0.75
);


)
//Final

Pseq([
//1. dream
Ptpar([
	0,~dream,
	76, ~alarm,
	48, ~dream2

],1),
//2. bedroom
Pseq([
	~bedroom1,
	Ptpar([0, ~bedroom1, 0, ~bedroom2, 15, ~sinkP]),
	Ptpar([0, ~bedroom1, 0, ~bedroom2, 0, ~bedroom3, 15, ~keysP, 45, ~keysP]),
	~doorP
]),

//3. city
Pseq([
	Ppar([~cityKick, ~citySnare]),
	Ptpar([0, ~cityKick, 0, ~citySnare, 0, ~cityHat, 0,  ~cityNoise]),
	Ptpar([0, ~cityKick, 0, ~citySnare, 0, ~cityHat, 0, ~cityNoise, 0,  ~cityMel2, 12, ~thudP]),
	Ptpar([0, ~cityKick, 0, ~citySnare, 0, ~cityHat, 0, ~cityNoise, 0,  ~cityMel1, 30, ~thudP, 0, ~truckP]),
	Ppar([~cityKick, ~citySnare]),
	~beepP,
	]),

//4. Office
Pseq([
	~officeMel0,
	Ppar([~officeMel1, ~officeMel2, ~officeType]),
	Ptpar([0, ~officeMel1, 0, ~officeMel2, 0, ~officeType, 0, ~convoP, 0, ~officeMel3]),
	~gunP
	]),
],1).play;
s.record;


