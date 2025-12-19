{ inputs, den, ... }:
{
  _module.args.__findFile = den.lib.__findFile;
  imports = [
    (inputs.den.namespace "com" true) # community
    (inputs.den.namespace "per" false) # personal
  ];
}
