function [simulated_data, parameters] = simulation_CA(parameters, model, study, shuff)
% SIMULATION_CA
%
% Simulates behavioural data from the Credit-Assignment (CA) models used
% in the manuscript.
%
% The function reproduces the task structure of either Study 1 or Study 2
% and returns simulated data in the same format as the empirical datasets,
% allowing the same fitting and analysis functions to be applied.
%
% INPUTS
%   parameters - nParticipant x nParameter matrix containing the model
%                parameters used to generate each simulated participant.
%                This has the same structure as the output of
%                my_CAmodel_fitter().
%
%   model      - Candidate CA model:
%
%                   'null'
%                   'certainty'
%                   'truth'
%                   'truthxcertainty'
%                   'truthxcertaintyxbr'
%
%                The 'truthxcertaintyxbr' model can only be
%                simulated using the Study 2 task.
%
%   study      - Study whose experimental structure should be simulated:
%
%                   1 = Study 1
%                   2 = Study 2
%
%   shuff      - Optional logical indicating whether each parameter should
%                be independently shuffled across participants before
%                simulation.
%
%                   false = use parameters as supplied (default)
%                   true  = independently shuffle each parameter column
%
% OUTPUTS
%   simulated_data
%              - Cell array with the same structure as the empirical data:
%
%                   simulated_data{:,1}
%                       Participant ID.
%
%                   simulated_data{:,2}
%                       Data ordered by bandit pair.
%
%                   simulated_data{:,3}
%                       Data ordered according to task sequence.
%
%   parameters - Parameters actually used for simulation. If shuff=true,
%                this contains the shuffled parameters.
%
% STUDY 1 TASK
%   - 8 blocks
%   - 3 bandit pairs per block
%   - 16 trials per bandit pair
%   - Each of the four sources occurs four times per bandit pair
%
% STUDY 2 TASK
%   - Same number of blocks, bandit pairs, and trials as Study 1
%   - Blocks alternate between Truth-Prevalent (TP; condition 1) and
%     Lie-Prevalent (LP; condition 2) environments
%   - Source prevalence:
%
%           TP: [0.125 0.125 0.375 0.375]
%           LP: [0.375 0.375 0.125 0.125]
%
% NOTES
%   - Bandit reward probabilities are 0.25 and 0.75.
%   - Source truth probabilities are 0, 1/3, 2/3, and 1.
%   - Q-values and perseveration values reset at each block.
%   - Simulated response times are set to Inf so all simulated choices are
%     included by the model-fitting function.


%% Input checks

if nargin < 4
    shuff = false;
end

valid_models = { ...
    'null', ...
    'certainty', ...
    'truth', ...
    'truthxcertainty', ...
    'truthxcertaintyxbr'};

if ~ismember(model, valid_models)
    error('Unknown model: %s', model)
end

if ~ismember(study, [1 2])
    error('study must be 1 or 2.')
end

if study == 1 && strcmp(model, 'truthxcertaintyxbr')
    error(['The truthxcertaintyxbr model can only be simulated ' ...
           'using the Study 2 task.'])
end


%% Optionally shuffle generating parameters across participants

if shuff
    for p = 1:size(parameters,2)
        parameters(:,p) = ...
            parameters(randperm(size(parameters,1)),p);
    end
end


%% Task settings

nTrialsGame  = 16;
nGamesBlock  = 3;
nBlocks      = 8;

nTrialsBlock = nTrialsGame * nGamesBlock;

% Reward probabilities of the two bandits
pReward = [0.25 0.75];

% Probability that each source reports the true outcome
cred = [0 1/3 2/3 1];

nAgents = length(cred);

% Three bandit pairs per block
game = repelem(1:nGamesBlock, nTrialsGame);


%% Study-specific task settings

switch study

    case 1

        % Each source occurs equally often within each bandit pair
        agents = repmat( ...
            repmat(1:nAgents, 1, nTrialsGame/nAgents), ...
            1, nGamesBlock);


    case 2

        % condition 1 = Truth-Prevalent
        % condition 2 = Lie-Prevalent
        condition = [1 2 1 2 1 2 1 2];

        pAgents = [ ...
            0.125 0.125 0.375 0.375; ...
            0.375 0.375 0.125 0.125];

end


%% Simulate participants

nSub = size(parameters,1);

simulated_data = cell(nSub,3);


for ss = 1:nSub

    simulated_data{ss,1} = ss;

    [CA, PERS, fQ, fP] = ...
        unpack_parameters(parameters(ss,:), model);


    %% Blocks

    for block = 1:nBlocks

        % Reset latent values at beginning of each block
        Q = zeros(nGamesBlock,2);
        P = zeros(nGamesBlock,2);


        % ---------------------------------------------------------------
        % Generate source sequence
        % ---------------------------------------------------------------

        if study == 1

            block_agents = agents;

        else

            block_agents = randsample( ...
                nAgents, ...
                nTrialsBlock, ...
                true, ...
                pAgents(condition(block),:));

        end


        % Randomly interleave sources and bandit pairs
        [rand_agents, rand_game] = ...
            shuffle_trials(block_agents, game);


        % Initialize trial variables
        chosen   = nan(1,nTrialsBlock);
        reward   = nan(1,nTrialsBlock);
        feedback = nan(1,nTrialsBlock);


        %% Trials

        for trial = 1:nTrialsBlock

            current_game = rand_game(trial);
            current_agent = rand_agents(trial);


            % -----------------------------------------------------------
            % Choice
            % -----------------------------------------------------------

            prob_bandit1 = 1 / ...
                (1 + exp( ...
                    diff(Q(current_game,:)) + ...
                    diff(P(current_game,:))));

            chosen(trial) = 1 + (rand > prob_bandit1);


            % -----------------------------------------------------------
            % True reward
            % -----------------------------------------------------------

            reward(trial) = ...
                2 * (double(rand < pReward(chosen(trial))) - 0.5);


            %% Source feedback

            if rand < cred(current_agent)
                feedback(trial) = reward(trial);
            else
                feedback(trial) = -reward(trial);
            end
            
            
            %% Feedback implied to be true
            
            if ismember(current_agent,[1 2])
                implied_feedback = -feedback(trial);
            else
                implied_feedback = feedback(trial);
            end
            
            
            %% Q-value update
            
            Q = (1-fQ) * Q;
            
            if strcmp(model,'truthxcertaintyxbr')
                ca = CA(condition(block),current_agent);
            else
                ca = CA(1,current_agent);
            end
            
            Q(current_game,chosen(trial)) = ...
                Q(current_game,chosen(trial)) + ...
                ca * implied_feedback;


            % -----------------------------------------------------------
            % Perseveration update
            % -----------------------------------------------------------

            P = (1-fP) * P;

            P(current_game,chosen(trial)) = ...
                P(current_game,chosen(trial)) + PERS;

        end


        %% ==============================================================
        %  Store data in task order
        %  ==============================================================

        simulated_data{ss,3}.block(block,:) = ...
            block * ones(1,nTrialsBlock);

        simulated_data{ss,3}.trial(block,:) = ...
            1:nTrialsBlock;

        simulated_data{ss,3}.agent(block,:) = ...
            rand_agents;

        simulated_data{ss,3}.cred(block,:) = ...
            cred(rand_agents);

        simulated_data{ss,3}.pick(block,:) = ...
            chosen;

        simulated_data{ss,3}.accuracy(block,:) = ...
            chosen == 2;

        simulated_data{ss,3}.reward(block,:) = ...
            (reward + 1) / 2;

        simulated_data{ss,3}.feedback(block,:) = ...
            (feedback + 1) / 2;

        simulated_data{ss,3}.game(block,:) = ...
            rand_game + nGamesBlock*(block-1);

        simulated_data{ss,3}.response_time(block,:) = ...
            inf(1,nTrialsBlock);

        simulated_data{ss,3}.timeouts(block,:) = ...
            zeros(1,nTrialsBlock);

        simulated_data{ss,3}.left(block,:) = ...
            round(rand(1,nTrialsBlock));


        % Study 2 base-rate condition
        if study == 2
            simulated_data{ss,3}.condition(block,:) = ...
                condition(block) * ones(1,nTrialsBlock);
        end


        %% ==============================================================
        %  Store data ordered by bandit pair
        %  ==============================================================

        for gg = 1:nGamesBlock

            row = nGamesBlock*(block-1) + gg;
            idx = find(rand_game == gg);

            simulated_data{ss,2}.block(row,:) = ...
                block * ones(1,nTrialsGame);

            simulated_data{ss,2}.trial(row,:) = ...
                1:nTrialsGame;

            simulated_data{ss,2}.game(row,:) = ...
                rand_game(idx);

            simulated_data{ss,2}.agent(row,:) = ...
                rand_agents(idx);

            simulated_data{ss,2}.cred(row,:) = ...
                cred(rand_agents(idx));

            simulated_data{ss,2}.pick(row,:) = ...
                chosen(idx);

            simulated_data{ss,2}.accuracy(row,:) = ...
                chosen(idx) == 2;

            simulated_data{ss,2}.reward(row,:) = ...
                (reward(idx) + 1) / 2;

            simulated_data{ss,2}.feedback(row,:) = ...
                (feedback(idx) + 1) / 2;

            simulated_data{ss,2}.response_time(row,:) = ...
                inf(1,nTrialsGame);

            % Inter-trial interval between presentations of same pair
            simulated_data{ss,2}.ITI(row,:) = ...
                [nan diff(idx)];

            % Final Q-values for this bandit pair
            simulated_data{ss,2}.Q(row,:) = ...
                Q(gg,:);


            if study == 2
                simulated_data{ss,2}.condition(row,:) = ...
                    condition(block) * ones(1,nTrialsGame);
            end

        end

    end


    %% Previous source/game information

    [simulated_data{ss,2}.prev_game, ...
     simulated_data{ss,2}.prev_agent] = ...
        get_previous(simulated_data{ss,3});

end

end


%% ========================================================================
%  PARAMETER UNPACKING
%  ========================================================================
function [CA, PERS, fQ, fP] = unpack_parameters(parameters, model)
% UNPACK_PARAMETERS
%
% Converts the fitted parameter vector into the 2 x 4 CA matrix used by
% the simulation.
%
% CA columns correspond to the four feedback sources.
%
% For all models except truthxcertaintyxbr, both rows are identical.
% For truthxcertaintyxbr:
%       row 1 = Truth-Prevalent condition
%       row 2 = Lie-Prevalent condition.


parameters = squeeze(parameters);


switch model

    case 'null'

        CArow = parameters(1) * [-1 -1 1 1];
        CA = [CArow; CArow];

        PERS = parameters(2);
        fQ   = parameters(3);
        fP   = parameters(4);


    case 'certainty'

        CArow = [ ...
            -parameters(2), ...
            -parameters(1), ...
             parameters(1), ...
             parameters(2)];

        CA = [CArow; CArow];

        PERS = parameters(3);
        fQ   = parameters(4);
        fP   = parameters(5);


    case 'truth'

        CArow = [ ...
            -parameters(1), ...
            -parameters(1), ...
             parameters(2), ...
             parameters(2)];

        CA = [CArow; CArow];

        PERS = parameters(3);
        fQ   = parameters(4);
        fP   = parameters(5);


    case 'truthxcertainty'

        CArow = parameters(1:4);
        CA = [CArow; CArow];

        PERS = parameters(5);
        fQ   = parameters(6);
        fP   = parameters(7);


    case 'truthxcertaintyxbr'

        CA = [ ...
            parameters(1:4); ...
            parameters(5:8)];

        PERS = parameters(9);
        fQ   = parameters(10);
        fP   = parameters(11);


    otherwise
        error('Unknown model: %s', model)

end

end


%% ========================================================================
%  SHUFFLE TRIAL ORDER
%  ========================================================================
function [agent, game] = shuffle_trials(agent, game)
% SHUFFLE_TRIALS
%
% Applies the same random permutation to the source and bandit-pair
% sequences.

agent = agent(:)';
game  = game(:)';

idx = randperm(length(agent));

agent = agent(idx);
game  = game(idx);

end


%% ========================================================================
%  PREVIOUS SOURCE / GAME
%  ========================================================================
function [games, agents] = get_previous(data)
% GET_PREVIOUS
%
% For each presentation of a bandit pair, identifies the source and game
% shown immediately before the current presentation of that pair.
%
% INPUT
%   data   - Simulated task-order data (simulated_data{ss,3}).
%
% OUTPUTS
%   games  - Previous game associated with each bandit-pair presentation.
%   agents - Previous source associated with each bandit-pair presentation.


nGames = max(data.game(:));
counter = ones(1,nGames);

games  = nan(nGames, size(data.game,2));
agents = nan(nGames, size(data.game,2));


for block = 1:size(data.game,1)

    for trial = 1:size(data.game,2)

        current_game = data.game(block,trial);
        occurrence = counter(current_game);

        if occurrence > 1

            games(current_game,occurrence) = ...
                data.game(block,trial-1);

            agents(current_game,occurrence) = ...
                data.agent(block,trial-1);

        end

        counter(current_game) = occurrence + 1;

    end
end

end