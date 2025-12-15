{ inputs, den, ... }:
{
  _module.args.__findFile = den.lib.__findFile;
  imports = [
    (inputs.den.namespace "eg" false) # TODO: remove
    (inputs.den.namespace "com" true) # community
    (inputs.den.namespace "inf" false) # infrastructure
    (inputs.den.namespace "per" false) # personal
  ];

}
