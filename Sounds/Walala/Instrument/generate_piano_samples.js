const fs = require("fs");
const path = require("path");

// Original additive piano timbre used by the in-game instrument. The generated
// WAVs are ordinary project assets and never touch the protected MyArt folder.
const output = __dirname;
const sampleRate = 22050;
const seconds = 1.65;
const frameCount = Math.floor(sampleRate * seconds);
const notes = ["c", "d", "e", "f", "g", "a", "b"];

function wav(samples) {
  const data = Buffer.alloc(samples.length * 2);
  samples.forEach((sample, index) => data.writeInt16LE(sample, index * 2));
  const header = Buffer.alloc(44);
  header.write("RIFF", 0);
  header.writeUInt32LE(36 + data.length, 4);
  header.write("WAVE", 8);
  header.write("fmt ", 12);
  header.writeUInt32LE(16, 16);
  header.writeUInt16LE(1, 20);
  header.writeUInt16LE(1, 22);
  header.writeUInt32LE(sampleRate, 24);
  header.writeUInt32LE(sampleRate * 2, 28);
  header.writeUInt16LE(2, 32);
  header.writeUInt16LE(16, 34);
  header.write("data", 36);
  header.writeUInt32LE(data.length, 40);
  return Buffer.concat([header, data]);
}

for (let octave = 4; octave <= 6; octave++) {
  for (let column = 0; column < notes.length; column++) {
    const midi = 12 * (octave + 1) + [0, 2, 4, 5, 7, 9, 11][column];
    const frequency = 440 * Math.pow(2, (midi - 69) / 12);
    const samples = new Array(frameCount);
    for (let i = 0; i < frameCount; i++) {
      const t = i / sampleRate;
      const attack = Math.min(1, t / 0.008);
      const body = Math.exp(-2.9 * t);
      const upper = Math.exp(-5.6 * t);
      const phase = 2 * Math.PI * frequency * t;
      const value = attack * (
        0.72 * Math.sin(phase) * body +
        0.19 * Math.sin(phase * 2.003) * upper +
        0.07 * Math.sin(phase * 3.009) * upper
      );
      samples[i] = Math.max(-32767, Math.min(32767, Math.round(value * 28500)));
    }
    const name = `piano_${notes[column]}${octave}.wav`;
    fs.writeFileSync(path.join(output, name), wav(samples));
  }
}
