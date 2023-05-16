% DMS2 State Machine Assembler (SMA)
%
% To be used for TrainingSection stages where animal
% is not required to cpoke. Instead, they can go
% direct to side poking to get reward. Removed from 
% the main SMA.m file for simplicity/readability.

function [varargout] = SMA_spoke(obj, action)

GetSoloFunctionArgs;


switch action

    %---------------------------------------------------------------%
    %          init                                                 %
    %---------------------------------------------------------------%
	case 'init'
        
        feval(mfilename, obj, 'prepare_next_trial');

    %---------------------------------------------------------------%
    %          prepare_next_trial                                   %
    %---------------------------------------------------------------%
	case 'prepare_next_trial'

        %%%%%%%%%%%%%%%%%%%%%%%%%%
        %%% SETUP THE HARDWARE %%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%

        %%% minimum time
        min_time= 2.5E-4;  % This is less than the minumum time allowed for a state transition.

        %%% define LEDs and water lines
        left1led    = bSettings('get', 'DIOLINES', 'left1led');
        center1led  = bSettings('get', 'DIOLINES', 'center1led');
        center2led  = bSettings('get', 'DIOLINES', 'center1water');
        right1led   = bSettings('get', 'DIOLINES', 'right1led');
        left1water  = bSettings('get', 'DIOLINES', 'left1water');
        right1water = bSettings('get', 'DIOLINES', 'right1water');


        %%% define state machine assembler
        sma = StateMachineAssembler('full_trial_structure','use_happenings', 1);

        %%% get water valve opening times (based on calibration)
        [LeftWValveTime, RightWValveTime] = WaterValvesSection(obj, 'get_water_times');

        %%% set the values based on correct side
        % TODO clean these up
        if strcmp(value(current_side), 'LEFT') 
            correct_response         = 'Lhi';
            incorrect_response       = 'Rhi'; 
            retry_incorrect_response = 'Rin';
            reward_water_dio         = left1water;
            correct_light_dio        = left1led;
            incorrect_light_dio      = right1led;
            reward_valve_time        = LeftWValveTime;

        elseif strcmp(value(current_side), 'RIGHT')
            correct_response         = 'Rhi';
            incorrect_response       = 'Lhi';
            retry_incorrect_response = 'Lin';
            reward_water_dio         = right1water;
            correct_light_dio        = right1led;
            incorrect_light_dio      = left1led;
            reward_valve_time        = RightWValveTime;
        end

        %%% scale water reward by stim multiple and/or give guide
        reward_valve_time    = reward_valve_time * stim_table{value(current_pair_idx), 5};

        if contains(value(give_type_implemented), 'water')
            give_valve_time  = reward_valve_time * give_water_frac;
            hit_valve_time   = reward_valve_time - give_valve_time;
        else
              hit_valve_time   = reward_valve_time;
        end

        %%% set up sounds (only could be used for replay)
        sa_replay_sound_id    = SoundManagerSection(obj, 'get_sound_id', 'SaReplaySound');
        sb_replay_sound_id    = SoundManagerSection(obj, 'get_sound_id', 'SbReplaySound');

        %%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%       WAVES        %%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%

        %%  Give light wave 
        if value(give_light_persist); loop = -1; else; loop = 1; end

        % Note extra_give_light_del_dur adds to pre_give_del_dur, such that
        % pre_give_del_dur + extra_give_light_del_dur = total time pre
        % light give. To use when shifting an animal off light -> water
        sma = add_scheduled_wave(sma, 'name', 'give_light_wave', ...
                                'preamble', value(extra_give_light_del_dur), ...
                                'sustain', value(give_light_dur), ...
                                'loop', loop,...
                                'DOut', correct_light_dio);

        %% Replay sound waves
        replay_sound_waves_on = '';
        replay_sound_waves_off = '';

        if value(replay_on)
            replay_sound_waves_on = 'sa_replay_wave + sb_replay_wave';


            if value(replay_n_loops) == -1
                replay_sound_waves_off = '-sa_replay_wave - sb_replay_wave';
            end

            sma = add_scheduled_wave(sma, 'name', 'sa_replay_wave', ...
                                          'preamble', 0, ...
                                          'sustain', value(replay_sa_dur) + value(replay_delay_dur) + value(replay_sb_dur) + value(replay_post_dur), ...
                                          'loop', value(replay_n_loops),...
                                          'sound_trig', sa_replay_sound_id);

            sma = add_scheduled_wave(sma, 'name', 'sb_replay_wave', ...
                                          'preamble', value(replay_sa_dur) + value(replay_delay_dur), ...
                                          'sustain', value(replay_sb_dur) + value(replay_post_dur), ...
                                          'loop', value(replay_n_loops),...
                                          'sound_trig', sb_replay_sound_id);
        end

        %%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%       STATES       %%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%
        
        %%% tracking of trial start- to be used in HistorySection
        %%% since it's unique to this SMA

        sma = add_state(sma, 'name', 'spoke_t_start',...
                             'self_timer', min_time,...
                             'input_to_statechange', {'Tup', 'pre_give_delay'});
        
        if strcmp(value(give_type_implemented), 'none')
            warning('in spoke sma, unless animal didnt drink water give, give should be on!')
            % not the best name but shouldn't be here often
            sma = add_state(sma, 'name', 'pre_give_delay',... 
                     'self_timer', value(give_del_dur),...
                     'input_to_statechange', {'Tup', 'wait_for_spoke'});
        else
            sma = add_state(sma, 'name', 'pre_give_delay',...
                     'self_timer', value(give_del_dur),...
                     'input_to_statechange', {'Tup', 'give_state';...
                                              correct_response, 'hit_state'});
            switch value(give_type_implemented)
            case 'water'
                sma = add_state(sma, 'name', 'give_state',...
                                     'self_timer', give_valve_time,...
                                     'output_actions', {'DOut', reward_water_dio},...
                                     'input_to_statechange', {'Tup', 'wait_for_spoke'});

            case 'light'
                sma = add_state(sma, 'name', 'give_state',...
                                     'self_timer', min_time,...
                                     'output_actions', {'SchedWaveTrig', 'give_light_wave'},...
                                     'input_to_statechange', {'Tup', 'wait_for_spoke'});

            case 'water_and_light'
                sma = add_state(sma, 'name', 'give_state',...
                                     'self_timer', give_valve_time,...
                                     'output_actions', {'DOut', reward_water_dio},...
                                     'input_to_statechange', {'Tup','current_state+1'});
                sma = add_state(sma,...
                                     'self_timer', min_time,...
                                     'output_actions', {'SchedWaveTrig', 'give_light_wave'},...
                                     'input_to_statechange', {'Tup', 'wait_for_spoke'});
            end
        end
        
        %%% water and/or light was delivered, time for the animal to choose
        %%% and they must get it correct
        sma = add_state(sma, 'name', 'wait_for_spoke',...
                             'self_timer', value(wait_for_spoke_dur),...
                             'input_to_statechange', {correct_response, 'hit_state';...
                                                      'Tup',            'no_answer_state'});

        %%% Hit state: animal made correct choice & gets reward
        sma = add_state(sma, 'name', 'hit_state',...
                             'self_timer', hit_valve_time,...
                             'output_actions', {'DOut', reward_water_dio,...
                                                'SchedWaveTrig', '-give_light_wave'},...
                             'input_to_statechange', {'Tup', 'drink_state'});
        
        sma = add_state(sma, 'name', 'drink_state',...
                             'self_timer', value(drinking_dur),...
                             'output_actions', {'DOut', correct_light_dio * value(reward_light),...
                                                'SchedWaveTrig', replay_sound_waves_on},...
                             'input_to_statechange', {'Tup', 'hit_cleanup_state'});

        % if using replay with an infinite loop, don't want to prep sound
        % for next trial until the replay is turned off so we need this state
        sma = add_state(sma, 'name', 'hit_cleanup_state',...
                             'self_timer', min_time,...
                             'output_actions', {'SchedWaveTrig', replay_sound_waves_off},...
                             'input_to_statechange', {'Tup', 'inter_trial_state'});
                            
        %%% No answer state: if the spoke state Tups and there is no penalty, the trial
        %%% cleans-up and moves on
        sma = add_state(sma, 'name','no_answer_state',...
                             'self_timer', min_time,...
                             'output_actions', {'SchedWaveTrig', '-give_light_wave'},...
                             'input_to_statechange', {'Tup', 'inter_trial_state'});                                    

        %%% Inter trial state- where the long iti can be implemented. Want
        %%% this separate from final state to be able to check
        %%% parsed_events for poke info in HistorySection.m
        sma = add_state(sma, 'name','inter_trial_state',...
                     'self_timer', value(inter_trial_dur),...
                     'input_to_statechange', {'Tup', 'final_state'});


        %%% Final states- control the inter trial interval and can vary depending on idt performance mult.
        sma = add_state(sma, 'name','final_state',...
                             'self_timer', min_time,...
                             'input_to_statechange', {'Tup', 'check_next_trial_ready'});
    
        % send SMA output back to DMS.m where dispatcher is called
        varargout{1} = sma;
        varargout{2} = {'final_state'}; 


    %---------------------------------------------------------------%
    %          reinit                                               %
    %---------------------------------------------------------------%
    case 'reinit'
        currfig = double(gcf);
        % Delete all SoloParamHandles who belong to this object and whose
        % fullname starts with the name of this mfile:
        delete_sphandle('owner', ['^@' class(obj) '$'],...
            'fullname', ['^' mfilename]);

        % Reinitialise at the original GUI position and figure:
        feval(mfilename, obj, 'init');

        % Restore the current figure:
        figure(currfig)
    %---------------------------------------------------------------%
    %          otherwise                                            %
    %---------------------------------------------------------------%
    otherwise
        error('Called action: %s, which is undefined.', action);
end

