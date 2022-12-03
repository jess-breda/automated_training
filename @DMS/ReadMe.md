# DMS
Delayed Match to Sample protocol and curricula for shaping.

## Repo Overview

`DMS.m` - Primary protocol script that organizes GUI initialization, trial preparation, and end of training logic (e.g. SQL uploads). Specific tasks are organized by subscripts described below.

`SMA.m` - Finite state machine that determines flow during a trial given the shaping variables. See [diagram]https://docs.google.com/drawings/d/1dHWPy06prrFCYhWpjr4Vq3TtNiAzAfdnH_HT0zrb06w/edit?usp=sharing).

`HistorySection.m` - tracks what happened on previous trial(s). For example, what was the stimulus? What did the animal answer? Etc.

`SideSection.m` - Samples which side (L/R) to use for next trial based on probabilities than can be influenced by `AntibiasSection.m` to control for motor biases.

`StimulusSection.m` - Given the side and current stimulus space, generates sound stimuli for the next trial. 

`ShapingSection.m` - This is where all the variables used to shape behavior are kept. For example, answer retry, reward-guides, etc. The settings of this section large dictate the `SMA.m`

`TrainingSection.m`- The curricula used for progressive automated training. Can control things like, what is the stimulus space, if penalties are on, and if performance is sufficient to move into next curricula stage.



