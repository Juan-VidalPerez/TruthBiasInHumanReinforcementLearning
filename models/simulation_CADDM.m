function [simulated_data, parameters] = simulation_CADDM(parameters, model, shuff)
% SIMULATION_CADDM
%
% Simulates Study 1 behaviour from the Credit-Assignment
% Drift-Diffusion Model (CA-DDM).
%
% INPUTS
%   parameters - nParticipant x nParameter matrix containing generating
%                parameters. Parameter structure must match the output of
%                my_CADDMmodel_fitter().
%
%   model      - CA-DDM model:
%
%                   'full'
%                   'ablate_cv'
%                   'ablate_t0'
%
%   shuff      - Optional logical.
%
%                   false = use supplied parameters (default)
%                   true  = independently shuffle each parameter across
%                           participants before simulation
%
%                Independent parameter shuffling is useful for parameter-
%                recovery simulations.
%
% OUTPUTS
%   simulated_data
%              - Simulated behavioural data in the same basic format as
%                the empirical data:
%
%                   simulated_data{ss,1}
%                       participant ID
%
%                   simulated_data{ss,2}
%                       trials ordered by bandit pair
%
%                   simulated_data{ss,3}
%                       trials in task order
%
%   parameters - Parameters actually used for simulation. If shuff=true,
%                these are the independently shuffled parameters.
%
%
% STUDY 1 TASK
%   - 8 blocks
%   - 3 bandit pairs per block
%   - 16 trials per bandit pair
%   - 48 trials per block
%   - 384 trials total
%   - 4 feedback sources presented equally often within each bandit pair
%
% SOURCE CODING
%   source 1 = 1-star, P(truth) = 0
%   source 2 = 2-star, P(truth) = 1/3
%   source 3 = 3-star, P(truth) = 2/3
%   source 4 = 4-star, P(truth) = 1
%
% NOTES
%   - Feedback stored in simulated_data is the literal source feedback.
%   - Feedback from 1-/2-star sources is sign-flipped before the Q update,
%     producing implied_feedback.
%   - Q and perseveration values reset at the beginning of each block.
%   - Choices and RTs are generated from the DDM.
%   - The CA-DDM is used only for Study 1, so there is no base-rate
%     condition in this simulation.


%% Defaults and input checks

if nargin < 3
    shuff = false;
end

valid_models = {'full','ablate_cv','ablate_t0'};

if ~ismember(model, valid_models)
    error( ...
        'Unknown model ''%s''. Use full, ablate_cv, or ablate_t0.', ...
        model);
end


%% Check parameter count

switch model
    case 'full'
        expected_npar = 18;

    case {'ablate_cv','ablate_t0'}
        expected_npar = 15;
end

if size(parameters,2) ~= expected_npar
    error( ...
        ['Model ''%s'' expects %d parameters, but the supplied matrix ' ...
         'contains %d columns.'], ...
        model, expected_npar, size(parameters,2));
end


%% Optionally shuffle parameters independently across participants

if shuff

    for p = 1:size(parameters,2)

        parameters(:,p) = ...
            parameters(randperm(size(parameters,1)),p);

    end

end


%% ========================================================================
%  TASK SETTINGS
%  ========================================================================

nTrialsGame  = 16;
nGamesBlock  = 3;
nBlocks      = 8;

nTrialsBlock = nTrialsGame * nGamesBlock;

% Reward probabilities of the two bandits
pReward = [0.25 0.75];

% Probability that each source reports the true outcome
cred = [0 1/3 2/3 1];

nSources = length(cred);


%% Source schedule
%
% Each source occurs exactly four times for each bandit pair.

sources_per_game = ...
    repmat(1:nSources,1,nTrialsGame/nSources);

sources = ...
    repmat(sources_per_game,1,nGamesBlock);


%% Bandit-pair schedule

games = repelem(1:nGamesBlock,nTrialsGame);


%% ========================================================================
%  SIMULATE PARTICIPANTS
%  ========================================================================

nSub = size(parameters,1);

simulated_data = cell(nSub,3);


for ss = 1:nSub

    simulated_data{ss,1} = ss;

    [CA, PERS, fQ, fP, cv, a, t0] = ...
        unpack_parameters(parameters(ss,:),model);


    %% -------------------------------------------------------------------
    %  BLOCKS
    %  -------------------------------------------------------------------

    for block = 1:nBlocks

        % Reset latent values at beginning of block
        Q = zeros(nGamesBlock,2);
        P = zeros(nGamesBlock,2);


        % Randomly interleave sources and bandit pairs while preserving
        % the balanced source schedule within each pair.
        [rand_sources, rand_games] = ...
            shuffle_trials(sources,games);


        % Preallocate trial variables
        chosen   = nan(1,nTrialsBlock);
        rt       = nan(1,nTrialsBlock);
        reward   = nan(1,nTrialsBlock);
        feedback = nan(1,nTrialsBlock);


        %% ---------------------------------------------------------------
        %  TRIALS
        %  ---------------------------------------------------------------

        for trial = 1:nTrialsBlock

            source = rand_sources(trial);
            game   = rand_games(trial);


            % -----------------------------------------------------------
            % DDM choice and reaction time
            % -----------------------------------------------------------

            choice_values = ...
                Q(game,:) + P(game,:);

            % Positive drift favours bandit 2 / upper boundary
            v = ...
                cv(source) * diff(choice_values);

            [rt_seconds, chosen(trial)] = ...
                sample_ddm( ...
                    v, ...
                    a(source), ...
                    t0(source));

            % Store RT in milliseconds
            rt(trial) = rt_seconds * 1000;


            % -----------------------------------------------------------
            % True outcome
            % -----------------------------------------------------------

            reward(trial) = ...
                2 * ...
                (double(rand < pReward(chosen(trial))) - 0.5);


            % -----------------------------------------------------------
            % Literal source feedback
            % -----------------------------------------------------------

            if rand < cred(source)

                feedback(trial) = ...
                    reward(trial);

            else

                feedback(trial) = ...
                    -reward(trial);

            end


            % -----------------------------------------------------------
            % Implied feedback
            % -----------------------------------------------------------
            %
            % Feedback from predominantly untruthful sources is inverted
            % before learning.

            if ismember(source,[1 2])

                implied_feedback = ...
                    -feedback(trial);

            else

                implied_feedback = ...
                    feedback(trial);

            end


            % -----------------------------------------------------------
            % Q-value update
            % -----------------------------------------------------------

            Q = (1-fQ) * Q;

            Q(game,chosen(trial)) = ...
                Q(game,chosen(trial)) + ...
                CA(source) * implied_feedback;


            % -----------------------------------------------------------
            % Perseveration update
            % -----------------------------------------------------------

            P = (1-fP) * P;

            P(game,chosen(trial)) = ...
                P(game,chosen(trial)) + PERS;

        end


        %% ==============================================================
        %  STORE DATA IN TASK ORDER
        %  ==============================================================

        simulated_data{ss,3}.block(block,:) = ...
            block * ones(1,nTrialsBlock);

        simulated_data{ss,3}.trial(block,:) = ...
            1:nTrialsBlock;

        simulated_data{ss,3}.agent(block,:) = ...
            rand_sources;

        simulated_data{ss,3}.cred(block,:) = ...
            cred(rand_sources);

        simulated_data{ss,3}.pick(block,:) = ...
            chosen;

        simulated_data{ss,3}.accuracy(block,:) = ...
            chosen == 2;

        simulated_data{ss,3}.reward(block,:) = ...
            (reward + 1) / 2;

        simulated_data{ss,3}.feedback(block,:) = ...
            (feedback + 1) / 2;

        % Global game index: 1,...,24
        simulated_data{ss,3}.game(block,:) = ...
            rand_games + nGamesBlock*(block-1);

        simulated_data{ss,3}.response_time(block,:) = ...
            rt;

        simulated_data{ss,3}.timeouts(block,:) = ...
            zeros(1,nTrialsBlock);

        simulated_data{ss,3}.left(block,:) = ...
            round(rand(1,nTrialsBlock));


        %% ==============================================================
        %  STORE DATA ORDERED BY BANDIT PAIR
        %  ==============================================================

        for gg = 1:nGamesBlock

            row = ...
                nGamesBlock*(block-1) + gg;

            idx = ...
                find(rand_games == gg);


            simulated_data{ss,2}.block(row,:) = ...
                block * ones(1,nTrialsGame);

            simulated_data{ss,2}.trial(row,:) = ...
                1:nTrialsGame;

            simulated_data{ss,2}.game(row,:) = ...
                rand_games(idx);

            simulated_data{ss,2}.agent(row,:) = ...
                rand_sources(idx);

            simulated_data{ss,2}.cred(row,:) = ...
                cred(rand_sources(idx));

            simulated_data{ss,2}.pick(row,:) = ...
                chosen(idx);

            simulated_data{ss,2}.accuracy(row,:) = ...
                chosen(idx) == 2;

            simulated_data{ss,2}.reward(row,:) = ...
                (reward(idx) + 1) / 2;

            simulated_data{ss,2}.feedback(row,:) = ...
                (feedback(idx) + 1) / 2;

            simulated_data{ss,2}.response_time(row,:) = ...
                rt(idx);

        end

    end

end

end


%% ========================================================================
%  PARAMETER UNPACKING
%  ========================================================================
function [CA, PERS, fQ, fP, cv, a, t0] = ...
    unpack_parameters(parameters, model)
% UNPACK_PARAMETERS
%
% Converts the fitted parameter vector into the quantities required by
% the CA-DDM simulation.
%
% SOURCE-DEPENDENT OUTPUTS
%   CA - 1 x 4 credit-assignment parameters
%   cv - 1 x 4 drift-rate scaling parameters
%   a  - 1 x 4 boundary-separation parameters
%   t0 - 1 x 4 non-decision times


parameters = squeeze(parameters);


switch model

    %% ===================================================================
    %  FULL MODEL
    %  ===================================================================
    case 'full'

        % 4 CA + PERS + fQ + fP + 3 cv + 4 a + 4 t0

        CA   = parameters(1:4);

        PERS = parameters(5);
        fQ   = parameters(6);
        fP   = parameters(7);

        % 1-star cv fixed to 1
        cv = [1 parameters(8:10)];

        a  = parameters(11:14);
        t0 = parameters(15:18);


    %% ===================================================================
    %  ABLATE SOURCE-DEPENDENT DRIFT SCALING
    %  ===================================================================
    case 'ablate_cv'

        % 4 CA + PERS + fQ + fP + 4 a + 4 t0

        CA   = parameters(1:4);

        PERS = parameters(5);
        fQ   = parameters(6);
        fP   = parameters(7);

        % Drift scaling fixed to 1 for all sources
        cv = ones(1,4);

        a  = parameters(8:11);
        t0 = parameters(12:15);


    %% ===================================================================
    %  ABLATE SOURCE-DEPENDENT NON-DECISION TIME
    %  ===================================================================
    case 'ablate_t0'

        % 4 CA + PERS + fQ + fP + 3 cv + 4 a + shared t0

        CA   = parameters(1:4);

        PERS = parameters(5);
        fQ   = parameters(6);
        fP   = parameters(7);

        % 1-star cv fixed to 1
        cv = [1 parameters(8:10)];

        a = parameters(11:14);

        % Single t0 shared across all sources
        t0 = parameters(15) * ones(1,4);


    otherwise

        error('Unknown model: %s',model)

end

end


%% ========================================================================
%  SHUFFLE TRIAL ORDER
%  ========================================================================
function [source, game] = shuffle_trials(source, game)
% SHUFFLE_TRIALS
%
% Applies the same random permutation to source and bandit-pair vectors,
% preserving their pairing.

A = [source; game];

A = A(:,randperm(size(A,2)));

source = A(1,:);
game   = A(2,:);

end


%% ========================================================================
%  DDM SAMPLER
%  ========================================================================
function [rt, choice] = sample_ddm(v, a, t0, z, dt)
% SAMPLE_DDM
%
% Simulates a single choice and reaction time from a drift-diffusion
% process.
%
% INPUTS
%   v   - Drift rate.
%   a   - Boundary separation.
%   t0  - Non-decision time in seconds.
%   z   - Relative starting point between the boundaries (default = 0.5).
%   dt  - Simulation time step in seconds (default = 0.001).
%
% OUTPUTS
%   rt      - Total reaction time in seconds.
%   choice  - Boundary reached:
%
%                 1 = lower boundary / bandit 1
%                 2 = upper boundary / bandit 2


if nargin < 5
    dt = 0.001;
end

if nargin < 4
    z = 0.5;
end


% Starting evidence
x = z * a;

t = 0;


while true

    % Euler-Maruyama update
    x = ...
        x + ...
        v*dt + ...
        randn*sqrt(dt);

    t = t + dt;


    % Upper boundary
    if x >= a

        rt = t + t0;

        choice = 2;

        return


    % Lower boundary
    elseif x <= 0

        rt = t + t0;

        choice = 1;

        return

    end

end

end