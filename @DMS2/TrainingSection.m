
%% TrainingSection.m
%
% Function that replaces SessionDefinition in Bcontrol. Creates GUI
% interface to switch between multiple curricula (each their own .m file)
% and stages within. Allows animals to run from common file that can be
% easily tracked on git.
% 
% Rewritten by Jess Breda in April 2023 given updates made to PWM2 by Jorge
% Yanar. Inspired by TrainingSection in TaskSwitch6
%
% Case Info:
%       init : 
%           where all internal and gui variables are created
%    
%       get_curriculum_stage_list :
%           Callback to curriculum variable. Given the slected curriculum,
%           will call 'get_stage_list' and return the appropriate menuparm
%           for the stage_name variable in the main DMS2 window that
%           contains all the stage info for the curriculum. Then calls
%           'get_curriculum_update' given the selected stage_number.
% 
%       update_stage_info :
%           Callback to stage_number variable. Given the selected stage_
%           number (within a curriculum), this will update all the
%           variables defined in that stage_number via 'get_curriculum_update' 
%           and update the stage_name menu item to match the satge_number. 
%       
%       increment_stage : 
%           When end of stage logic is hit in curriculum stage number and
%           autotrain is on, this will update to the next stage. Will reset
%           the stage specific history variables (e.g. n_days_stage) upon
%           stage switch and call get_curriculum_update to update stage
%           variables.
%
%           The next stage can be passed as an argument, or assumed to be 
%           the next numerical stage. 
%           
%           Example call from stage 4:
%               TrainingSection(obj, 'increment_stage'); % goes to stage 5
%               TrainingSection(obj, 'increment_stage', 3); % goes to stage 3
%       
%       prepare_next_trial : 
%           On every trial, calls 'get_curriculum_update' and tracks the
%           number of trials in stage. Could also be used to implement and
%           keep track of helper variables.
% 
%       get_curriculum_update :
%           Given a selected curriculum, calls 'get_update' to update any
%           variables specific to that stage/trial count/previous result/etc.
%           This is the workhorse of TrainingSection and the 'get_update'
%           case for a specific curriculum will read like a
%           SessionDefintion file (but better!).
%       
%       implement_helper : (NOT IN USE)
%           The idea behind this case is to have a paramerterized way of
%           giving animals a set of easier trials if performance in a
%           previous window is poor. The type of easy trial is up to the
%           user. For example, you could turn on water give for 10 trials,
%           or turn off delay growth for 50 trials. 
%
%           It's not currently in use because there is still a lot of fine
%           tuning that needs to be done in this protocol before automated
%           setbacks can happen. Keeping it here for future user.
% 
%       end_session: 
%           Tracks the number of days in a stage & training. One could also
%           add End of Day (EOD) logic here. But as currently written,
%           stage switch logic happens within a session (like a completion
%           string in SessionDefinition).
%

function [x, y] = TrainingSection(obj, action, varargin)

GetSoloFunctionArgs(obj);

switch action,

    % ------------------------------------------------------------------
    %              INIT
    % ------------------------------------------------------------------

    case 'init'
        x=varargin{1};
        y=varargin{2};
        
        % TODO- add in when curricula folder is functional         
        % need to access trianing files on path
%         curriculum_folder = 'C:\ratter\Protocols\@DMS2\curricula';
%         if ~isfolder(curriculum_folder); addpath(curriculum_folder); end
    
        %% HELPER VARS- NOT CURRENTLY IN USE 
        %%% violation threshold & toggle for helper
        NumeditParam(obj, 'helper_violation_threshold',0.70, x, y,'labelfraction',0.65,...
            'TooltipString', 'violation rate to trigger a subset of eaiser trials',...
            'label', 'violation threshold', 'position', [x y 150 20]);
        ToggleParam(obj, 'violation_helper_on', 1, x, y, 'position', [x+150 y 50 20], ...
            'OffString', 'OFF', 'OnString',  'ON', ...
            'TooltipString', 'If on, & helper on will be used a threshold for setting animal back');
        next_row(y, 1);
        
        %%% hit threshold & toggle for helper
        NumeditParam(obj, 'helper_hit_threshold',0.55, x, y,'labelfraction',0.65,...
            'TooltipString', 'hit rate to trigger a subset of eaiser trials',...
            'label', 'hit threshold', 'position', [x y 150 20]);
        ToggleParam(obj, 'hit_helper_on', 1, x, y, 'position', [x+150 y 50 20], ...
            'OffString', 'OFF', 'OnString',  'ON', ...
            'TooltipString', 'If on, & helper on will be used a threshold for setting animal back');
        next_row(y, 1);
        
        %%% helper block params: helper_type and counter for number of helper blocks
        MenuParam(obj, 'helper_type', {'give'; 'error';},...
            1, x, y, 'position', [x y 100 20], 'label', 'type', 'labelfraction', 0.40,...
            'TooltipString', 'type of help given if block is entered');
        DispParam(obj, 'helper_block_counter', 0, x,y, 'labelfraction', 0.5,...
            'label', 'n blocks', 'position', [x+100 y 100 20],...
            'TooltipString', 'number of times a helper block has been entered this session');
        next_row(y, 1);
        
        %%% helper block params: n trials back to assess, n easier trials to give and
        %%% internal counter for exiting out of block
        MenuParam(obj, 'helper_trials_back', {'10'; '25'; '50'; '75'; '100'},...
            2, x, y, 'position', [x y 100 20], 'label', 'n back', 'labelfraction', 0.40,...
            'TooltipString', 'number trials back to look at to apply threshold');
        NumeditParam(obj, 'helper_trials_give',10, x, y,'labelfraction',0.5,...
            'TooltipString', 'number of easier trials to give',...
            'label', 'give', 'position', [x+100 y 100 20]);
        SoloParamHandle(obj, 'helper_trial_counter', 'value', 0);
        next_row(y, 1);

        %%% helper: performance based logic to temporarily move into an easier version
        %%% of the current trial structure
        ToggleParam(obj, 'helper_on', 0, x, y, 'position', [x y 100 20], ...
            'OffString', 'Helper OFF', 'OnString',  'Helper ON', ...
            'TooltipString', sprintf(['NOT YET IMPLEMENTED!!',...
                '\nIf on, search over window given thresholds to determine short setback']));
        DispParam(obj, 'in_helper_block', 'FALSE', x, y, 'position', [x+100 y 100 20],...
            'label', 'In Block', 'labelfraction', 0.55,...
            'TooltipString', 'Whether the animal is currently in a helper block.');
        next_row(y, 1.5);

        %% STAGE & CURRICULA INFORMATION
        %%% --- TRAINING HISTORY VARS SUBWINDOW START ---
        % create window & build from bottom up
        ToggleParam(obj, 'train_history_vars', 0, x,y, 'position', [x y 200 20],...
            'OnString', 'Train History Vars Showing',...
            'OffString', 'Train History Vars Hidden', 'TooltipString', 'Show/hide train history vars info');
        set_callback(train_history_vars, {mfilename, 'show_hide_train_history_vars_window'});
        oldx=x; oldy=y; parentfig=double(gcf);
        
        SoloParamHandle(obj, 'train_history_vars_window', 'value',...
            figure('Position', [750 600 210 130],...
                   'MenuBar', 'none',...
                   'Name', 'Train History Vars',...
                   'NumberTitle', 'off',...
                   'CloseRequestFcn', [mfilename '(' class(obj) ', ''hide_train_history_vars_window'');']));
        set(gcf, 'Visible', 'off');
        x=5;y=5;
        
        % curriculum vars
        ToggleParam(obj, 'stage_4_viol_off_grown', 0, x, y, 'position', [x y 200 20],...
            'OnString', 'Stg 4 Viol Off Grow Complete',...
            'OffString', 'Stg 4 ViolOff Grow NOT Complete',...
            'TooltipString', 'If EOS logic was hit for stage 2 for a given animal');
        next_row(y,1); 

        ToggleParam(obj, 'stage_3_left_block', 0, x, y, 'position', [x y 100 20],...
            'OnString', 'Stg 3 L Blk ON',...
            'OffString', 'Stg 3 R Blk OFF',...
            'TooltipString', 'If in a left block of trials');        
        ToggleParam(obj, 'stage_3_right_block', 0, x, y, 'position', [x+100 y 100 20],...
            'OnString', 'Stg 3 R Blk ON',...
            'OffString', 'Stg 3 R Blk OFF',...
            'TooltipString', 'If in a right block of trials');
        next_row(y,1);
        ToggleParam(obj, 'stage_3_blocks', 0, x, y, 'position', [x y 200 20],...
            'OnString', 'Stg 3 Blocks Enabled',...
            'OffString', 'Stg 3 Blocks Disable',...
            'TooltipString', 'If blocked L/R structure should be used'); 
        next_row(y,1);
        ToggleParam(obj, 'stage_2_spoke_completed', 0, x, y, 'position', [x y 200 20],...
            'OnString', 'Stg 2 Complete',...
            'OffString', 'Stg 2 NOT Complete',...
            'TooltipString', 'If EOS logic was hit for stage 2 for a given animal');
        next_row(y,1);
        ToggleParam(obj, 'stage_1_spoke_completed', 0, x, y, 'position', [x y 200 20],...
            'OnString', 'Stg 1 Complete',...
            'OffString', 'Stg 1 NOT Complete',...
            'TooltipString', 'If EOS logic was hit for stage 1 for a given animal');
        next_row(y,1);
        SubheaderParam(obj,'lab1', 'TS_JB_LWG_FDEL History',x,y,'position', [x+10 y 180 20]);
        
        % back to main window
        x=oldx; y=oldy; figure(parentfig);
        %%% --- TRAINING HISTORY VARS SUBWINDOW END ---

        %%% Stage history
        next_row(y,1);
        NumeditParam(obj, 'n_days_stage',0, x, y, 'labelfraction', 0.55,...
            'label','n days','position', [x y 100 20],...
            'TooltipString', 'number of consecutive days in training stage');
        NumeditParam(obj, 'n_days_training',0, x, y, 'labelfraction', 0.55,...
            'label','total sess.','position', [x+100 y 100 20],...
            'TooltipString', 'number of days/sessions total');
        next_row(y,1);
       
        DispParam(obj, 'n_trials_stage',0, x, y, 'labelfraction', 0.55,...
            'label','n trials','position', [x y 100 20],...
            'save_with_settings', 1,...
            'TooltipString', 'number of trials done in stage in a session');
        %%% Auto stage switch upon completion logic
        ToggleParam(obj, 'stage_switch_auto', 1, x, y, 'position', [x+100 y 100 20], ...
            'OffString', 'Autotrain OFF', 'OnString',  'Autotrain ON', ...
            'TooltipString', sprintf(['\nIf on, switches automatically between training',... 
                            'stages via increment_stage assuming end of stage logic is',...
                            'written in .m file for the selected curriculum & stage']));
        
        % big jump up and building from the top down
        % save coords to be able to build ontop of this section in GUI
        next_row(y, 7);
        topx = x; topy=y; 
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%% Curriculum. Used to specify training stages. %%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        SubheaderParam(obj, 'title', mfilename, x, y); next_row(y, -1);
        MenuParam(obj, 'curriculum', {'JB_LWG_FDEL';'JB_cpoke_nofix'; ...
                                      'JB_cpoke_nofix_2';'JB_cpoke_fix';},...
            1, x, y, 'position', [x y 200 20], 'label', 'Curriculum',...
            'labelfraction', 0.35, 'TooltipString', 'The current curriculum.');
        next_row(y, -1);
        DispParam(obj, 'curriculum_description', 'Curriculum description',...
            x, y, 'label', '', 'position', [x y 200 20], 'labelfraction', 0.01,...
            'TooltipString', 'Description of the current curriculum.');
        next_row(y, -1.8);

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%% Generate list of training stages. %%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % %% Stage info (internal)
        SoloParamHandle(obj, 'stage_list', 'value', {});
        SoloParamHandle(obj, 'stage_name', 'value', '');
        SoloParamHandle(obj, 'previous_stage', 'value', '');
        
        % persits mirrors stage name, but not reinstantiated each trial
        SoloParamHandle(obj, 'stage_name_persist', 'value', '');
        
        %%% Stage info (GUI)
        MenuParam(obj, 'stage_number', {'1','2','3','4','5','6','7','8','9','10'},...
            1, x, y, 'position', [x y 40 35], 'label', '', 'labelfraction', 0.1,...
            'TooltipString', sprintf(['given selected curriculum, what stage',...
                            '\nthe animal is currently in. This is also how you',...
                            '\nmanually switch stages']));
        % called stage_number_callback in PWM2
        set_callback(stage_number, {mfilename, 'update_stage_info'});
        
        
        % GUI locations for stage name param because the menuparam needs to
        % change depending on the curricula selected (stages are different)
        % set_stage_list makes this menuparam
        SoloParamHandle(obj, 'x_stage_name', 'value', x);
        SoloParamHandle(obj, 'y_stage_name', 'value', y);
        % called set_stage_list in PWM2
        set_callback(curriculum, {mfilename, 'get_curriculum_stage_list', value(x_stage_name), value(y_stage_name)});
        next_row(y, -2);
        
        % Describe the given curriculums stage
        DispParam(obj, 'stage_description', 'Stage description', x, y, 'label',...
            '', 'position', [x y-5 200 35], 'labelfraction', 0.01, 'TooltipString',...
            'Description of the current stage.');

        %% SEND OUT VARIABLES
        % add helper here if you want to use it
        SoloFunctionAddVars('HistorySection', 'ro_args',...
          {'stage_name', 'curriculum', 'stage_number', 'stage_name_persist'});
        SoloFunctionAddVars('HistorySection', 'rw_args',...
            {'n_trials_stage', 'n_days_stage', 'n_days_training'}); 
        SoloFunctionAddVars('ShapingSection', 'ro_args',...
          {'n_trials_stage', 'n_days_stage', 'n_days_training'});
        DeclareGlobals(obj, 'ro_args', {'stage_name', 'stage_number', 'stage_name_persist'});
        
        % Send out vars to individual curriculum files
        training_section_send_out_vars = get_name(get_sphandle('owner', '@DMS2', 'funcowner', 'TrainingSection'));
        
        SoloFunctionAddVars('TS_JB_cpoke_nofix', 'rw_args', training_section_send_out_vars);
        SoloFunctionAddVars('TS_JB_LWG_FDEL','rw_args', training_section_send_out_vars);
        
        % TODO add in functionality for curricula folder like this:
%         SoloFunctionAddVars('curricula', 'rw_args', training_section_vars);
        

        %% INITALIZES STAGE INFO GIVEN LOAD
        % Set appropriate initial values, toggles, etc for this curriculum/stage
        TrainingSection(obj, 'get_curriculum_stage_list', value(x_stage_name), value(y_stage_name));
        TrainingSection(obj, 'get_curriculum_update');
        x = topx; y=topy;

    %---------------------------------------------------------------%
    %          get_curriculum_stage_list                            %
    %---------------------------------------------------------------%
    case 'get_curriculum_stage_list'
        % Loads the appropriate stage list from the current curriculum, and
        % constructs the stage_name MenuParam to allow the user to view
        % stage numbers and names.
        
        disp('running get_curriculum_stage_list !!!!!!!!!!!!!!!!!!!!');
        x = varargin{1};
        y = varargin{2};
        switch value(curriculum)

        case 'JB_cpoke_nofix' % this is old will be deleted.
            stage_list.value = {'1: spoke autorewd',...
                                '2: center side no snds give',...
                                '3: center snds side give no viol',...
                                '4: grow stim',...
                                '5: grow pre',...
                                '6: grow post',...
                                '7: grow delay (0.2)',...
                                '8: require rule, never',...
                                '9: grow delay btw snds (2.4)',...
                                '10: discrete delays',...
                                '11: add stimuli'};
        case 'JB_cpoke_nofix_2'
            stage_list.value = TS_JB_cpoke_nofix(obj, 'get_stage_list');
        
        case 'JB_LWG_FDEL'
            stage_list.value = TS_JB_LWG_FDEL(obj, 'get_stage_list');
                
            
        end
        
        % create menu param
        MenuParam(obj, 'stage_name', value(stage_list), value(stage_number),...
            x, y, 'label', 'Stage', 'position', [x+40 y 160 35],...
            'labelfraction', 0.35,...
            'TooltipString', sprintf(['FOR DISPLAY ONLY use this for context',...
                                      '\nfor picking your next stage number',...
                                      '\ncontains stage name for all stages in curricula']));
        
        % update internal vars
        stage_name_persist.value = value(stage_name);
        previous_stage.value = value(stage_name);
        
        % update variables given curricula
        TrainingSection(obj, 'get_curriculum_update');
    
    %---------------------------------------------------------------%
    %          update_stage_info                                    %
    %---------------------------------------------------------------%
    case 'update_stage_info'
        % Callback that is triggered when the stage_number menu param is
        % changed. Will take the selected stage number and the currently
        % selected curricula to update (1) all the variables defined in the
        % curricula's selected stage number (2) the selected value in
        % stage_name for visual purposes.

        fprintf('************************* update_stage_info callback called!\n');

        % set to highest defined stage if user selected one out of range
        if value(stage_number) > length(value(stage_list))
              stage_number.value = length(value(stage_list));
            warning('stage is out of range for this curricula!');
        end

        % update counters
        n_trials_stage.value = 0;
            % Only set n_days_stage back to 1 if we're modifying stage number while running.
            % TODO: Modify so that it resets if we change stage_number before we start running,
            %       but does not trigger if we're loading.
        if n_done_trials ~= 0
            n_days_stage.value = 1;
        end
        
        % update the internal tracking vars
        previous_stage.value = value(stage_name_persist);
        stage_name.value = stage_list{value(stage_number)};
        stage_name_persist.value = stage_list{value(stage_number)};
        
        % set stage-specific settings for the selected curricula
        TrainingSection(obj, 'get_curriculum_update');
    

    %---------------------------------------------------------------%
    %          increment_stage                                      %
    %---------------------------------------------------------------%   
    case 'increment_stage'        
        % Move into next stage if auto train was on (this is the case that
        % does end of stage or day logic)
        %   input (optional): stage (num) to switch to, Otherwise will move
        %                     to the next numerical stage (e.g. 4 -> 5)
        
        if value(stage_switch_auto)
            fprintf('****** Current stage number: %i\n', value(stage_number));
            
            % save previous stage string
            previous_stage.value = value(stage_name_persist);
            
            % move to a specified stage if specified by the case call,
            % otherwise just move to the next numerical stage
            if length(varargin) == 1 
                next_stage = varargin{1};
                stage_number.value = next_stage;  
            else
                % move up if you're not in the last stage
                if value(stage_number) < length(value(stage_list)) 
                    stage_number.value = value(stage_number) + 1;  
                end
            end 
            
            % update stage name strings
            stage_name.value = stage_list{value(stage_number)};
            stage_name_persist.value = value(stage_name); % might not need?
            
            % update counters
            n_trials_stage.value = 0;
            n_days_stage.value = 1;
            
            % get new curriculum presets for stage
            TrainingSection(obj, 'get_curriculum_update');
            fprintf('****** Updated stage number: %i\n', value(stage_number));
        else
            fprintf('******** Stage %s\n******** completed, but auto switch is off.',...
                value(stage_name));
        end
    
    %---------------------------------------------------------------%
    %          prepare_next_trial                                   %
    %---------------------------------------------------------------%
    case 'prepare_next_trial'
        % check to see if we need to switch into a new stage given
        % performance & toggle
        if n_done_trials > 0
            n_trials_stage.value = value(n_trials_stage) + 1;
            feval(mfilename, obj, 'get_curriculum_update');
        end
        
        % HELPER- not in use but possible implementation:
         % check to see if helper needs to be turned on given
         % performance & toggle
         % if value(helper_on)
             % TrainingSection(obj, 'implement_helper', value(helper_tyle));
         % end


    %---------------------------------------------------------------%
    %          get_curriculum_update                                %
    %---------------------------------------------------------------%
    case 'get_curriculum_update'
        %%% Set parameters across sections for the curriculum/training stage
        switch value(curriculum)
                        
        case 'JB_cpoke_nofix_2'
            TS_JB_cpoke_nofix(obj, 'get_update', value(stage_number));
            
        case 'JB_LWG_FDEL'
            TS_JB_LWG_FDEL(obj, 'get_update', value(stage_number));

            

        %---------------------------------------------------%
        %         JB_cpoke_nofix                            %
        %---------------------------------------------------%
        % NOTE- old way of calling this. Will be removed.
        % DMS protocol that does not require animal to fixate,
        % written by JRB June 2022. 
        % Goal: learn cpoke, learn rule, grow sa/sb delay, extend stim
        case 'JB_cpoke_nofix'
            switch value(stage_number)
            case 1
                stage_description.value = 'spoke --> rwd';
                %%% initialize on the first trial
                if (value(n_trials_stage)==0)
                    %%% task parameters
                    SMA_set.value = 'spoke';
                    stimuli_on.value = false;
                    give_type_set.value = 'water_and_light';
                    inter_trial_dur_type.value = 'sampled';
                    inter_trial_sample_mean.value = 1;
                end

                %%% Auto stage-switch logic
                if (value(n_done_trials) >= value(helper_trials_give))
                   TrainingSection(obj, 'increment_stage');
                end

            case 2
                stage_description.value = 'cpoke spoke --> rwd';
                %%% initialize on the first trial
                if (value(n_trials_stage)==0)
                    %%% task parameters
                    give_type_set.value = 'water_and_light';
                    SMA_set.value = 'cpoke';
                    stimuli_on.value = false;
                    temp_error_penalty.value = true;
                    retry_type.value = 'multi';
                end

                %%% Auto stage-switch logic
                if (value(n_done_trials) >= 50) && (value(frac_correct) > .7) && ...
                   (value(n_days_stage) > 0)
                   TrainingSection(obj, 'increment_stage');
                end

            case 3
                stage_description.value = 'cpoke snd spoke, no viol';
                %%% initialize on the first trial
                if (value(n_trials_stage)==0)
                    %%% task parameters
%                     reward_type.value = 'give';
%                     stimuli_on.value = true;
%                     wait_for_spoke_Tup_forgiveness.value = true;
%                     temp_error_penalty.value = true;
%                     retry_type.value = 'single';
                    violation_penalty.value = false;
                
                    %%% durations 
                    pre_dur.value = 0.1;
                    delay_dur.value = 0.1;
                    stimulus_dur.value = 0.2;
                    post_dur.value = 0.1;

                    %%% delays (incase of reset)
                    delay_warm_up.value = false;
                 end

                %%% Auto stage-switch logic
                %%% TODO- make this early spoke based
                if (value(n_trials_stage) >= 100) &&...
                        (value(n_early)/value(n_trials_stage)) < 0.5 
                    TrainingSection(obj, 'increment_stage');
                end

            case 4
                stage_description.value = 'grow stim';
                %%% initialize on the first trial
                if (value(n_trials_stage)==0)
                    %%% task parameters
                    stimuli_on.value = true;
                    violation_penalty.value = true;
                    violation_dur.value = 0.5;
                    violation_dur_type.value = 'growing';
                    violation_fixed_growth_rate.value = 0.025;
                    error_dur.value = 0.5;
                    error_dur_type.value = 'stable';
                    
                    if value(n_days_stage) == 0
                        temp_error_penalty.value = false;
                        retry_type.value = 'N/A';
                        reward_type.value = 'poke';
                        wait_for_spoke_Tup_forgiveness.value = false;                        
                    end
                        
                
                    % growth stimulus
                    stimulus_min.value = 0.1;
                    stimulus_dur.value = value(stimulus_min);
                    stimulus_growth.value = 'fixed';
                    stimulus_warm_up.value = true;
                    pre_growth.value = 'none';
                    delay_growth.value = 'none';
                    post_growth.value = 'none';
                    
                end
                              
                %%% Auto stage-switch logic
                if (value(frac_violations) < 0.5) && (value(stimulus_dur) >= value(stimulus_max))
                    TrainingSection(obj, 'increment_stage');
                end
               
            case 5   
                stage_description.value = 'grow pre';
                %%% initialize on the first trial
                if (value(n_trials_stage)==0)
                    %%% task parameters
                    stimuli_on.value = true;
                    violation_penalty.value = true;
                    violation_dur.value = 0.5;
                    violation_dur_type.value = 'growing';
                    violation_fixed_growth_rate.value = 0.025;
                    error_dur.value = 0.5;
                    error_dur_type.value = 'stable';
                    
                    if value(n_days_stage) == 0
                        temp_error_penalty.value = false;
                        wait_for_spoke_Tup_forgiveness.value = false;
                        retry_type.value = 'N/A';
                        reward_type.value = 'poke';                        
                    end                    
                
                    % grow pre
                    pre_min.value = 0.1;
                    pre_dur.value = value(pre_min);
                    pre_growth.value = 'fixed';
                    pre_warm_up.value = true;
                    % turn off other growth
                    stimulus_growth.value = 'none';
                    delay_growth.value = 'none';
                    post_growth.value = 'none';
                else
                    % grow settling in dur to 0.2 in tandem
                    if value(settling_in_dur) < 0.2
                        settling_in_dur.value = value(pre_dur);
                    end
                end
                
                %%% Auto stage-switch logic
                if (value(frac_violations) < 0.5) && (value(pre_dur) >= value(pre_max))
                    TrainingSection(obj, 'increment_stage');
                end
            case 6   
                stage_description.value = 'grow post';
                %%% initialize on the first trial
                if (value(n_trials_stage)==0)
                    %%% task parameters
                    stimuli_on.value = true;
                    violation_penalty.value = true;
                    violation_dur.value = 0.5;
                    violation_dur_type.value = 'growing';
                    violation_fixed_growth_rate.value = 0.025;
                    error_dur.value = 0.5;
                    error_dur_type.value = 'stable';

                    if value(n_days_stage) == 0
                        temp_error_penalty.value = false;
                        retry_type.value = 'N/A';
                        reward_type.value = 'poke';
                        wait_for_spoke_Tup_forgiveness.value = false;
                    end                         
                    
                    post_min.value = 0.05;
                    post_dur.value = value(post_min);
                    post_growth.value = 'fixed';
                    post_warm_up.value = true;
                    % turn off other growth
                    pre_growth.value = 'none'; 
                    stimulus_growth.value = 'none';
                    delay_growth.value = 'none';

                end
                
                %%% Auto stage-switch logic
                if (value(frac_violations) < 0.5) && (value(post_dur) >= value(post_max))
                    TrainingSection(obj, 'increment_stage');
                end
            case 7  
                stage_description.value = 'grow delay (0.2)';
                %%% initialize on the first trial
                if (value(n_trials_stage)==0)
                    %%% task parameters
                    stimuli_on.value = true;
                    violation_penalty.value = true;
                    violation_dur.value = 0.5;
                    violation_dur_type.value = 'growing';
                    violation_fixed_growth_rate.value = 0.025;
                    error_dur.value = 0.5;
                    error_dur_type.value = 'stable';               

                    if value(n_days_stage) == 0
                        temp_error_penalty.value = false;
                        retry_type.value = 'N/A';
                        reward_type.value = 'poke';
                        wait_for_spoke_Tup_forgiveness.value = false;
                    end      
                    
                    delay_min.value = 0.1;
                    delay_max.value = 0.2;
                    delay_dur.value = value(delay_min);
                    delay_growth.value = 'fixed';
                    delay_warm_up.value = true;
                    % turn off other growth
                    pre_growth.value = 'none';
                    stimulus_growth.value = 'none';
                    post_growth.value = 'none';

                end
                
                %%% Auto stage-switch logic
                if (value(frac_violations) < 0.5) && (value(delay_dur) >= 0.2)
                    TrainingSection(obj, 'increment_stage');
                end                   
            
            case 8
                stage_description.value = 'learn rule w/ never reward';
                %%% initialize on the first trial
                if (value(n_trials_stage)==0)
                    %%% task parameters
                    
                    stimuli_on.value = true;
                    wait_for_spoke_Tup_forgiveness.value = false;


%                     helper_hit_threshold.value = 0.5;
%                     helper_violation_threshold.value = 0.7;
                
                    %%% delays (incase of reset)
                    pre_growth.value = 'none';
                    stimulus_growth.value = 'none';
                    delay_growth.value = 'none';
                    post_growth.value = 'none';
                    
                    %%% initializations for first day in the stage give
                    %%% user more flexibility to modify these on animal
                    %%% by animal basis since this stage takes the longest
                    if (value(n_days_stage) == 1)
                        reward_type.value = 'poke';
                        violation_penalty.value = true;
                        violation_dur.value = 0.5;
                        violation_dur_type.value = 'growing';
                        error_dur.value = 0.5;
                        error_dur_type.value = 'growing';
                        temp_error_penalty.value = false;
                        retry_type.value = 'N/A';
                    end
                    
                end
                                    
%                 %%% helper
%                 if (value(n_trials_stage) >= 30) && (value(n_days_stage) < 5) && ...
%                     (value(helper_block_counter) < 3)
%                     helper.value = true;
%                     helper_type.value = 'error'; 
%                 end

                %%% Auto stage-switch logic
                if (value(n_trials_stage) >= 100) && (value(frac_correct) > .9) && ...
                    (value(frac_violations) < 0.4)
                    TrainingSection(obj, 'increment_stage');
                end

            case 9
                stage_description.value = 'grow delay between sa/sb';
                %%% initialize on the first trial
                if (value(n_trials_stage) == 0)
                    %%% task parameters
                    reward_type.value = 'poke';
                    stimuli_on.value = true;
                    wait_for_spoke_Tup_forgiveness.value = false;
                    temp_error_penalty.value = false;
                    retry_type.value = 'N/A';

                    %%% growth
                    delay_min.value = 0.2;
                    delay_max.value = 2.5;
                    delay_dur.value = value(delay_min);
                    delay_growth.value = 'fixed';
                    delay_warm_up.value = 'fixed';

                    if value(n_days_stage) == 1
                        delay_growth_type.value = 'fixed';
                        delay_fixed_growth_rate.value = 1.50; % ~360 valid trials to reach
                        delay_fixed_growth_unit.value = '%';
                    end 
                end
                %%% Auto stage-switch logic
                if (value(delay_dur) >= value(delay_max)) && (value(frac_violations) < 0.3) && ...
                    (value(frac_correct) > 0.7)
                    TrainingSection(obj, 'increment_stage');
                end 

            case 10
                stage_description.value = 'discrete delays';
                %%% initialize on the first trial                
                if (value(n_trials_stage) == 0)
                    %%% task parameters
                    reward_type.value = 'poke';
                    stimuli_on.value = true;
                    wait_for_spoke_Tup_forgiveness.value = false;
                    temp_error_penalty.value = false;
                    retry_type.value = 'N/A';
                    
                    %%% disrete delays
                    delay_growth.value = 'none';
                    delay_warm_up.value = 'none';
                    delay_growth_type.value = 'discrete';
                end
%                 %%% Auto stage-switch logic
%                 if (value(n_days_stage) > 0) && (value(frac_violations) < 0.3) && ...
%                         (value(n_done_trials) > 5)
%                     stage_number.value = 7;
%                 end 
%                 
            case 11
                stage_description.value = 'add stimuli';
                % TODO

            end % End JB_cpoke_nofix stage_number

        end % end switch value(curriculum)
    
    %---------------------------------------------------------------%
    %          implement_helper                                     %
    %---------------------------------------------------------------%
    case 'implement_helper'
        %% NOT IN USE- possible use case
        % This cased is called if helper is on. Allows you to check 
        % animal performance (hit and/or violation rate) to determine if
        % animal should get a specififed number of easier trials. 
        % Trials can be modulated by give, error type, whatever you choose.
        % Once helper trials are up, will switch animal back to original 
        % curriculum. This function does not change the stage the animal is
        % in, but helper trials are tracked in the history section
        %
        % NOTE: as written there is currently no logic determining how many 
        % trials between helper blocks, only the maximum number of blocks 
        % in a session

        helper_type = varargin{1};

        %%% If not already in helper block, check if performance qualifies
        %%% and if so switch to helper block based on helper_type
        if strcmp(value(in_helper_block), 'FALSE')
            % Check hit performance
            if value(hit_helper_on)
                % grab performance metric from historysection
                hit_performance = value(eval(['Last' helper_trials_back 'TrialPerf']));
                if hit_performance < value(helper_hit_threshold)
                    hit_setback = 1; % reched threshold
                else
                    hit_setback = -1; % haven't reached threshold
                end
            else
                hit_setback = 0; % hit based helper is not on, ingore
            end
            % Check violation performance
            if value(violation_helper_on)
                % grab performance metric from historysection
                violation_performance = value(eval(['Last' helper_trials_back 'TrialViol']));
                if violation_performance < value(helper_violation_threshold)
                    violation_setback = 1; % reached threshold
                else
                    violation_setback = -1; % haven't reached threshold
                end
            else
                violation_setback = 0; % violation based helper is not on, ignore
            end
            % Turn on helper if threshold(s) hit
            if (hit_setback + violation_setback) > 0
                in_helper_block.value = 'TRUE';
                helper_trial_counter.value = value(helper_trials_give);
                
                % NOTE- this currently would not work with DMS2, but is an
                % example of how you would turn off/on certain variables
                % given a 'helper_type'. It would override whatever was get
                % in 'get_curriculum_update' since it is called after it.
                % set values based on helper_type
                switch value(helper_type)
                case 'water_give'
                    give_type.value          = 'water';
                case 'error'
                    temp_error_penalty.value = true;
                    retry_type.value         = 'single';
                
                otherwise
                    error('helper type unknown! cannot switch into helper block');
                end
            end 
        %%% If we are already in a helper block, check if we need to switch
        %%% back out of it
        elseif strcmp(value(in_helper_block), 'TRUE')
            helper_trial_counter.value = value(helper_trial_counter) - 1;
            if value(helper_trial_counter) == 0
                in_helper_block.value = 'FALSE';
                helper_block_counter.value = value(helper_block_counter) + 1;

                % set values based on helper_type
                switch value(helper_type)
                case 'give'
                    give_type.value          = 'none';
                case 'error'
                    temp_error_penalty.value = false;
                    retry_type.value         = 'N/A';
                otherwise
                    error('helper type unknown! cannot switch out of helper block');
                end
            end 
        end

    %---------------------------------------------------------------%
    %          get_curriculum_eod_logic                             %
    %---------------------------------------------------------------%
    % NOTE: currently only written for TS_JB_LWG_FDEL curriculum
    % Run EOD logic for specific curriculum/stage
    case 'get_curriculum_eod_logic'
        switch value(curriculum)
        case 'JB_LWG_FDEL'
            TS_JB_LWG_FDEL(obj, 'get_eod_logic', value(stage_number));
        end

        
    %---------------------------------------------------------------%
    %          end_session                                          %
    %---------------------------------------------------------------%

    case 'end_session'
        % update history of stage
        n_days_stage.value = value(n_days_stage) + 1;
        n_days_training.value = value(n_days_training) + 1;

        TrainingSection(obj, 'get_curriculum_eod_logic');

        % HELPER- not in use but example implementation
        % clean up helper if session ended in with helper block on
        % 
        % helper_block_counter.value = 0;
        % helper_trial_counter.value = 0;
        % in_helper_block.value = 'FALSE';
      
        % EOD stage logic- how to implemented
        % if(value(stage_switch_auto)==1) && specigic stage lgic
        %   feval(mfilename, obj, 'increment_stage'); 
        % end

    %---------------------------------------------------------------%
    %          show/hide/close                                      %
    %---------------------------------------------------------------%

    case 'show_hide_train_history_vars_window'
        if train_history_vars == 0, set(value(train_history_vars_window), 'Visible', 'off');
        else                        set(value(train_history_vars_window), 'Visible', 'on');
        end
    case 'hide_train_history_vars_window'
        set(value(train_history_vars_window), 'Visible', 'off'); train_history_vars.value = 0;
    case 'close'
        delete(value(train_history_vars_window));
   

    otherwise
        warning('DMS2/TrainingSection - Unknown action: %s\n', action);


end
