function [parameters, fval] = fit_CAmodel(data, model)
% MY_CAMODEL_FITTER
%
% Fits the Credit-Assignment (CA) reinforcement-learning models used in
% the manuscript using participant-level maximum-likelihood estimation.
%
% Each participant is fitted from 10 random starting points using FMINCON.
% The solution with the highest log-likelihood is retained.
%
% INPUTS
%   data  - Empirical or simulated behavioural data.
%
%           Cell array with:
%               data{:,1} - participant ID
%               data{:,2} - data ordered by bandit pair
%               data{:,3} - data ordered according to task sequence
%
%           Model fitting uses data{:,3}.
%
%   model - Candidate CA model:
%
%               'null'
%                   One CA parameter shared across source certainty and
%                   truthfulness.
%
%               'certainty'
%                   CA differs according to source certainty.
%
%               'truth'
%                   CA differs according to source truthfulness.
%
%               'truthxcertainty'
%                   Four source-specific CA parameters, allowing both
%                   truthfulness and certainty to modulate learning.
%
%               'truthxcertaintyxbr'
%                   Eight CA parameters: four sources x two base-rate
%                   conditions. This model can only be fitted to Study 2
%                   data containing the variable .condition.
%
% OUTPUTS
%   parameters - nParticipant x nParameter matrix containing the maximum-
%                likelihood parameter estimates for each participant.
%
%   fval       - nParticipant x 1 vector containing the maximum
%                log-likelihood for each participant.
%
% NOTES
%   - Each participant is fitted from 10 random starting points.
%   - FMINCON minimizes negative log-likelihood.
%   - Only choices with reaction time > 150 ms contribute to likelihood.
%   - Q-values and perseveration values reset at the start of each block.
%   - The base-rate model requires Study 2 data containing .condition.
%   - PARFOR is used across fitting attempts for each participant.


%% Settings

nSub = size(data,1);
nAttempts = 10;
nFits = nSub * nAttempts;

% Base-rate model is only defined for Study 2
if strcmp(model, 'truthxcertaintyxbr') && ...
        ~isfield(data{1,3}, 'condition')

    error(['The truthxcertaintyxbr model requires Study 2 data ' ...
           'containing the variable .condition.']);
end

[lb, ub, startPoints] = get_bounds(model, nFits);

options = optimset( ...
    'Display', 'off', ...
    'FunValCheck', 'on');


%% Preallocate outputs

parameters = nan(nSub, size(startPoints,2));
fval = nan(nSub,1);

parameters_tmp = nan(nFits, size(startPoints,2));
nll_tmp = nan(nFits,1);


%% Fit participants

counter = 0;

for ss = 1:nSub

    curr_data = data{ss,3};
    idx = counter + (1:nAttempts);

    parfor aa = 1:nAttempts

        [parameters_tmp(counter+aa,:), nll_tmp(counter+aa)] = ...
            fmincon( ...
                @(p) objective_CA(p, curr_data, model), ...
                startPoints(counter+aa,:), ...
                [], [], [], [], ...
                lb, ub, ...
                [], options);

    end

    % Keep fitting attempt with highest log-likelihood
    [fval(ss), bestAttempt] = max(-nll_tmp(idx));

    parameters(ss,:) = ...
        parameters_tmp(idx(bestAttempt),:);

    counter = counter + nAttempts;

end

end


%% ========================================================================
%  PARAMETER BOUNDS AND STARTING POINTS
%  ========================================================================
function [lb, ub, sp] = get_bounds(model, nFits)
% GET_BOUNDS
%
% Defines parameter bounds and random starting points.
%
% INPUTS
%   model - Candidate model name.
%   nFits - Total number of fitting attempts.
%
% OUTPUTS
%   lb - Lower parameter bounds.
%   ub - Upper parameter bounds.
%   sp - nFits x nParameter matrix of random starting points.


ub_CA   = 10;
ub_PERS = 5;


switch model

    case 'null'
        % CA, PERS, fQ, fP
        lb = [-ub_CA, -ub_PERS, 0, 0];
        ub = [ ub_CA,  ub_PERS, 1, 1];

        sp = [ ...
            random_symmetric(nFits,1,ub_CA), ...
            random_symmetric(nFits,1,ub_PERS), ...
            rand(nFits,2)];


    case {'certainty','truth'}
        % Two CA parameters, PERS, fQ, fP
        lb = [-ub_CA*ones(1,2), -ub_PERS, 0, 0];
        ub = [ ub_CA*ones(1,2),  ub_PERS, 1, 1];

        sp = [ ...
            random_symmetric(nFits,2,ub_CA), ...
            random_symmetric(nFits,1,ub_PERS), ...
            rand(nFits,2)];


    case 'truthxcertainty'
        % Four source-specific CA parameters, PERS, fQ, fP
        lb = [-ub_CA*ones(1,4), -ub_PERS, 0, 0];
        ub = [ ub_CA*ones(1,4),  ub_PERS, 1, 1];

        sp = [ ...
            random_symmetric(nFits,4,ub_CA), ...
            random_symmetric(nFits,1,ub_PERS), ...
            rand(nFits,2)];


    case 'truthxcertaintyxbr'
        % Eight CA parameters:
        % four sources x two base-rate conditions
        lb = [-ub_CA*ones(1,8), -ub_PERS, 0, 0];
        ub = [ ub_CA*ones(1,8),  ub_PERS, 1, 1];

        sp = [ ...
            random_symmetric(nFits,8,ub_CA), ...
            random_symmetric(nFits,1,ub_PERS), ...
            rand(nFits,2)];


    otherwise
        error('Unknown model: %s', model)

end

end


%% ========================================================================
%  NEGATIVE LOG-LIKELIHOOD
%  ========================================================================
function nll = objective_CA(parameters, data, model)
% OBJECTIVE_CA
%
% Computes the negative log-likelihood of the observed choices.
%
% Feedback from untruthful sources (1-/2-star) is sign-flipped before
% updating Q so that learning is always expressed relative to the outcome
% implied to be true.

[CA, PERS, fQ, fP] = unpack_parameters(parameters, model);

nBlocks = size(data.block,1);
nTrialsBlock = size(data.block,2);
nTrials = nBlocks * nTrialsBlock;

chosen = data.pick';
agent  = data.agent';
game   = mod(data.game' - 1,3) + 1;

% Literal source feedback (-1 / +1)
feedback = 2 * (data.feedback' - 0.5);

% Sign-flip feedback from untruthful sources
feedback_flip = ones(size(agent));
feedback_flip(ismember(agent,[1 2])) = -1;

implied_feedback = feedback .* feedback_flip;

if strcmp(model,'truthxcertaintyxbr')
    condition = data.condition';
else
    condition = ones(size(chosen));
end

if isfield(data,'response_time')
    RT = data.response_time';
else
    RT = inf(size(chosen));
end

loglik_choice = nan(1,nTrials);
counter = 0;

for trial = 1:nTrials

    % Reset values at the beginning of each block
    if mod(trial,nTrialsBlock) == 1
        Q = zeros(3,2);
        P = zeros(3,2);
    end

    if ismember(chosen(trial),1:2)

        %% Choice likelihood

        if RT(trial) > 150

            counter = counter + 1;

            choice_value = ...
                Q(game(trial),:) + P(game(trial),:);

            choice_value = choice_value - max(choice_value);

            loglik_choice(counter) = ...
                choice_value(chosen(trial)) - ...
                log(sum(exp(choice_value)));

        end


        %% Q update

        Q = (1-fQ) * Q;

        Q(game(trial),chosen(trial)) = ...
            Q(game(trial),chosen(trial)) + ...
            CA(condition(trial),agent(trial)) * ...
            implied_feedback(trial);


        %% Perseveration update

        P = (1-fP) * P;

        P(game(trial),chosen(trial)) = ...
            P(game(trial),chosen(trial)) + PERS;

    end
end

loglik_choice = loglik_choice(1:counter);
nll = -sum(loglik_choice);

end




%% ========================================================================
%  PARAMETER UNPACKING
%  ========================================================================
function [CA, PERS, fQ, fP] = unpack_parameters(parameters, model)
% UNPACK_PARAMETERS
%
% Converts the fitted parameter vector into the 2 x 4 CA matrix.
%
% Feedback from untruthful sources is already sign-flipped in the fitting
% function, so CA parameters do not contain additional sign inversions.

parameters = squeeze(parameters);

switch model

    case 'null'

        CArow = parameters(1) * ones(1,4);
        CA = [CArow; CArow];

        PERS = parameters(2);
        fQ   = parameters(3);
        fP   = parameters(4);


    case 'certainty'

        % Source order: 1-star, 2-star, 3-star, 4-star
        % Certain:   1-star and 4-star
        % Uncertain: 2-star and 3-star
        CArow = [ ...
            parameters(2), ...
            parameters(1), ...
            parameters(1), ...
            parameters(2)];

        CA = [CArow; CArow];

        PERS = parameters(3);
        fQ   = parameters(4);
        fP   = parameters(5);


    case 'truth'

        CArow = [ ...
            parameters(1), ...
            parameters(1), ...
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
            parameters(1:4);
            parameters(5:8)];

        PERS = parameters(9);
        fQ   = parameters(10);
        fP   = parameters(11);


    otherwise
        error('Unknown model: %s', model)

end

end


%% ========================================================================
%  RANDOM STARTING POINTS
%  ========================================================================
function x = random_symmetric(nRows, nCols, bound)
% RANDOM_SYMMETRIC
%
% Generates uniformly distributed random starting points in
% [-bound, +bound].

x = (rand(nRows,nCols) - 0.5) * 2 * bound;

end