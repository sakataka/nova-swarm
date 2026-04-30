declare module "jsfxr" {
  export const sfxr: {
    toWebAudio(synthdef: unknown, audiocontext: AudioContext): AudioBufferSourceNode;
  };
}
