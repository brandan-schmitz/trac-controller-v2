const appTitle = 'TRAC Waterpark Controller';

const featureIds = [
  'play_structure',
  'river_fountains',
  'yellow_slide',
  'lazy_river',
  'center_jets',
  'blue_slide',
];

const featureLabels = {
  'play_structure': 'Play Structure',
  'river_fountains': 'River Fountains',
  'yellow_slide': 'Yellow Slide',
  'lazy_river': 'Lazy River',
  'center_jets': 'Center Jets',
  'blue_slide': 'Blue Slide',
};

const mqttFeatureCmd = 'trac/pool/features/{id}/cmd';
const mqttFeatureState = 'trac/pool/features/+/state';
const mqttEstopCmd = 'trac/pool/estop/cmd';
const mqttEstopState = 'trac/pool/estop/state';
const mqttUiStatus = 'trac/pool/panel/ui/status';
const mqttHeartbeat = 'trac/pool/heartbeat';

const connYellowSeconds = 6;
const connRedSeconds = 12;