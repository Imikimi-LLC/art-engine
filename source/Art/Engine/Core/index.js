// generated by Neptune Namespaces v4.x.x
// file: Art/Engine/Core/index.js

(module.exports = require('./namespace'))
.includeInNamespace(require('./Core'))
.addModules({
  AnimatedElementMixin:   require('./AnimatedElementMixin'),
  CanvasElement:          require('./CanvasElement'),
  Element:                require('./Element'),
  ElementBase:            require('./ElementBase'),
  ElementFactory:         require('./ElementFactory'),
  EpochedElementMixin:    require('./EpochedElementMixin'),
  EventedElementMixin:    require('./EventedElementMixin'),
  GlobalEpochCycle:       require('./GlobalEpochCycle'),
  IdleEpoch:              require('./IdleEpoch'),
  Lib:                    require('./Lib'),
  NamedElementPropValues: require('./NamedElementPropValues'),
  SourceToBitmapCache:    require('./SourceToBitmapCache'),
  StandardImport:         require('./StandardImport'),
  StateEpoch:             require('./StateEpoch')
});
require('./Drawing');
require('./EpochLayout');