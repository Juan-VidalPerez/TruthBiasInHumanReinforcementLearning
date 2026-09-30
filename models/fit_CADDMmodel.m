function [parameters, loglik] = fit_CADDMmodel(data, model)
% MY_CADDMMODEL_FITTER
%
% Fits the Credit-Assignment Drift-Diffusion Model (CA-DDM) used in
% Study 1.
%
% Each participant is fitted from 10 random starting points using FMINCON.
% The solution with the highest log-likelihood is retained.
%
% INPUTS
%   data  - Study 1 behavioural data.
%
%           Cell array with:
%               data{:,1} - participant ID
%               data{:,2} - data ordered by bandit pair
%               data{:,3} - data ordered according to task sequence
%
%           Model fitting uses data{:,3}.
%
%   model - CA-DDM variant:
%
%               'full'
%                   Source-specific drift scaling (cv), boundary
%                   separation (a), and non-decision time (t0).
%
%               'ablate_cv'
%                   Drift scaling fixed to cv = 1 for all sources;
%                   source-specific a and t0 are retained.
%
%               'ablate_t0'
%                   A single t0 is shared across sources;
%                   source-specific cv and a are retained.
%
% OUTPUTS
%   parameters - nParticipant x nParameter matrix containing maximum-
%                likelihood parameter estimates.
%
%   loglik     - 1 x nParticipant vector containing the maximum
%                log-likelihood for each participant.
%
% PARAMETERIZATION
%   All models contain:
%       4 CA parameters      - one per feedback source
%       PERS                 - perseveration
%       fQ                   - Q-value forgetting
%       fP                   - perseveration forgetting
%
%   full:
%       + 3 free cv parameters (1-star cv fixed to 1)
%       + 4 source-specific a
%       + 4 source-specific t0
%       = 18 parameters
%
%   ablate_cv:
%       + cv fixed to 1 for all sources
%       + 4 source-specific a
%       + 4 source-specific t0
%       = 15 parameters
%
%   ablate_t0:
%       + 3 free cv parameters (1-star cv fixed to 1)
%       + 4 source-specific a
%       + 1 shared t0
%       = 15 parameters
%
% NOTES
%   - Only trials with RT > 150 ms contribute to the likelihood.
%   - Feedback from 1-/2-star sources is sign-flipped before learning, so
%     CA is expressed in terms of the outcome implied to be true.
%   - Q and perseveration values reset at the start of each block.
%   - Drift-diffusion likelihoods are evaluated with WFPT_ROBUST.


%% Settings

nSub = size(data,1);
nAttempts = 10;

validModels = {'full','ablate_cv','ablate_t0'};

if ~ismember(model, validModels)
    error( ...
        'Unknown model ''%s''. Use: full, ablate_cv, or ablate_t0.', ...
        model);
end

switch model
    case 'full'
        nParam = 18;

    case {'ablate_cv','ablate_t0'}
        nParam = 15;
end

options = optimset( ...
    'Display','off', ...
    'FunValCheck','on');


%% Preallocate outputs

parameters = nan(nSub,nParam);
loglik = nan(1,nSub);


%% Fit participants

for ss = 1:nSub

    currData = data{ss,3};

    [lb, ub, startPoints] = ...
        get_bounds(model, nAttempts, currData);

    fittedParameters = nan(nAttempts,nParam);
    nll = nan(1,nAttempts);

    parfor attempt = 1:nAttempts

        [fittedParameters(attempt,:), nll(attempt)] = ...
            fmincon( ...
                @(p) objective_CADDM(p,currData,model), ...
                startPoints(attempt,:), ...
                [],[],[],[], ...
                lb,ub, ...
                [],options);

    end

    % Retain attempt with highest log-likelihood
    [loglik(ss), bestAttempt] = max(-nll);

    parameters(ss,:) = fittedParameters(bestAttempt,:);

end

end


%% ========================================================================
%  PARAMETER BOUNDS AND STARTING POINTS
%  ========================================================================
function [lb, ub, sp] = get_bounds(model, nFits, data)
% GET_BOUNDS
%
% Defines parameter bounds and random starting points for the CA-DDM.
%
% INPUTS
%   model - CA-DDM model variant.
%   nFits - Number of random starting points.
%   data  - Single-participant task data.
%
% OUTPUTS
%   lb - Lower parameter bounds.
%   ub - Upper parameter bounds.
%   sp - nFits x nParameter matrix of random starting points.


ubCA   = 10;
ubPERS = 5;
ubCV   = 3;

lbA = 1e-3;
ubA = 4;


%% Upper bound on non-decision time

switch model

    case {'full','ablate_cv'}

        % Source-specific t0 must be below the participant's minimum
        % observed RT for that source.
        rtMin = nan(1,4);

        for source = 1:4
            validRT = data.response_time( ...
                data.response_time > 150 & ...
                data.agent == source);

            rtMin(source) = min(validRT) / 1000;
        end


    case 'ablate_t0'

        % Shared t0 must be below the participant's overall minimum RT.
        validRT = data.response_time(data.response_time > 150);
        rtMin = min(validRT) / 1000;

end


%% Bounds

switch model

    case 'full'
        % [CA(4), PERS, fQ, fP, cv(3), a(4), t0(4)]

        lb = [ ...
            -ubCA*ones(1,4), ...
            -ubPERS, ...
            zeros(1,2), ...
            zeros(1,3), ...
            lbA*ones(1,4), ...
            zeros(1,4)];

        ub = [ ...
             ubCA*ones(1,4), ...
             ubPERS, ...
             ones(1,2), ...
             ubCV*ones(1,3), ...
             ubA*ones(1,4), ...
             rtMin];

        sp = [ ...
            random_symmetric(nFits,4,ubCA), ...
            random_symmetric(nFits,1,ubPERS), ...
            rand(nFits,2), ...
            rand(nFits,3)*ubCV, ...
            rand(nFits,4)*(ubA-lbA) + lbA, ...
            rand(nFits,4).*rtMin];


    case 'ablate_cv'
        % [CA(4), PERS, fQ, fP, a(4), t0(4)]

        lb = [ ...
            -ubCA*ones(1,4), ...
            -ubPERS, ...
            zeros(1,2), ...
            lbA*ones(1,4), ...
            zeros(1,4)];

        ub = [ ...
             ubCA*ones(1,4), ...
             ubPERS, ...
             ones(1,2), ...
             ubA*ones(1,4), ...
             rtMin];

        sp = [ ...
            random_symmetric(nFits,4,ubCA), ...
            random_symmetric(nFits,1,ubPERS), ...
            rand(nFits,2), ...
            rand(nFits,4)*(ubA-lbA) + lbA, ...
            rand(nFits,4).*rtMin];


    case 'ablate_t0'
        % [CA(4), PERS, fQ, fP, cv(3), a(4), t0]

        lb = [ ...
            -ubCA*ones(1,4), ...
            -ubPERS, ...
            zeros(1,2), ...
            zeros(1,3), ...
            lbA*ones(1,4), ...
            0];

        ub = [ ...
             ubCA*ones(1,4), ...
             ubPERS, ...
             ones(1,2), ...
             ubCV*ones(1,3), ...
             ubA*ones(1,4), ...
             rtMin];

        sp = [ ...
            random_symmetric(nFits,4,ubCA), ...
            random_symmetric(nFits,1,ubPERS), ...
            rand(nFits,2), ...
            rand(nFits,3)*ubCV, ...
            rand(nFits,4)*(ubA-lbA) + lbA, ...
            rand(nFits,1)*rtMin];

end

end


%% ========================================================================
%  NEGATIVE LOG-LIKELIHOOD
%  ========================================================================
function nll = objective_CADDM(parameters, data, model)
% OBJECTIVE_CADDM
%
% Computes the negative log-likelihood of choices and reaction times under
% the CA-DDM.
%
% Feedback from untruthful sources is sign-flipped before the Q-value
% update, so CA parameters are expressed in implied-feedback coordinates.


%% Parameters

[CA, PERS, fQ, fP, cv, a, t0] = ...
    unpack_parameters(parameters,model);


%% Behavioural data

nBlocks = size(data.block,1);
nTrialsBlock = size(data.block,2);
nTrials = nBlocks*nTrialsBlock;

chosen = data.pick';
agent  = data.agent';
game   = mod(data.game' - 1,3) + 1;

% Literal feedback emitted by the source (-1 / +1)
feedback = 2*(data.feedback' - 0.5);

% Feedback recoded as the outcome implied to be true.
% Sources 1 and 2 are untruthful, so their feedback is sign-flipped.
feedback_flip = ones(size(agent));
feedback_flip(ismember(agent,[1 2])) = -1;

implied_feedback = feedback .* feedback_flip;

if isfield(data,'response_time')
    RT = data.response_time';
else
    RT = inf(size(chosen));
end


%% Trial-wise likelihood

loglik = nan(1,nTrials);
counter = 0;

for trial = 1:nTrials

    % Reset latent values at each block
    if mod(trial,nTrialsBlock) == 1
        Q = zeros(3,2);
        P = zeros(3,2);
    end


    if ismember(chosen(trial),1:2)

        %% DDM likelihood

        if RT(trial) > 150

            netValue = ...
                Q(game(trial),:) + P(game(trial),:);

            % Drift is expressed relative to the selected option,
            % preserving the convention of the original implementation.
            v = cv(agent(trial)) * ...
                (netValue(3-chosen(trial)) - ...
                 netValue(chosen(trial)));

            decisionTime = ...
                RT(trial)/1000 - t0(agent(trial));

            if decisionTime > 0.01

                logDensity = ...
                    wfpt_robust( ...
                        decisionTime, ...
                        v, ...
                        a(agent(trial)));

                if ~isnan(logDensity) && ~isinf(logDensity)

                    counter = counter + 1;
                    loglik(counter) = logDensity;

                end
            end
        end


        %% Q-value update

        Q = (1-fQ)*Q;
        
        Q(game(trial),chosen(trial)) = ...
            Q(game(trial),chosen(trial)) + ...
            CA(agent(trial))*implied_feedback(trial);

        %% Perseveration update

        P = (1-fP)*P;

        P(game(trial),chosen(trial)) = ...
            P(game(trial),chosen(trial)) + PERS;

    end
end


%% Negative log-likelihood

loglik = loglik(1:counter);
nll = -sum(loglik);

end


%% ========================================================================
%  PARAMETER UNPACKING
%  ========================================================================
function [CA, PERS, fQ, fP, cv, a, t0] = ...
    unpack_parameters(parameters, model)
% UNPACK_PARAMETERS
%
% Converts the fitted parameter vector into the quantities used by the
% CA-DDM.
%
% The 1-star source drift-scaling parameter is fixed to cv = 1 in models
% where source-specific cv parameters are estimated.


parameters = squeeze(parameters);


switch model

    case 'full'
        % 4 CA + PERS + fQ + fP + 3 cv + 4 a + 4 t0

        CA   = parameters(1:4);
        PERS = parameters(5);
        fQ   = parameters(6);
        fP   = parameters(7);

        cv = [1 parameters(8:10)];
        a  = parameters(11:14);
        t0 = parameters(15:18);


    case 'ablate_cv'
        % 4 CA + PERS + fQ + fP + 4 a + 4 t0

        CA   = parameters(1:4);
        PERS = parameters(5);
        fQ   = parameters(6);
        fP   = parameters(7);

        cv = ones(1,4);
        a  = parameters(8:11);
        t0 = parameters(12:15);


    case 'ablate_t0'
        % 4 CA + PERS + fQ + fP + 3 cv + 4 a + shared t0

        CA   = parameters(1:4);
        PERS = parameters(5);
        fQ   = parameters(6);
        fP   = parameters(7);

        cv = [1 parameters(8:10)];
        a  = parameters(11:14);
        t0 = parameters(15)*ones(1,4);

end

end


%% ========================================================================
%  RANDOM STARTING POINTS
%  ========================================================================
function x = random_symmetric(nRows,nCols,bound)
% RANDOM_SYMMETRIC
%
% Uniform random values in [-bound,+bound].

x = (rand(nRows,nCols)-0.5)*2*bound;

end


%% ========================================================================
%  WIENER FIRST-PASSAGE TIME LOG-DENSITY
%  ========================================================================
function logP = wfpt_robust(t,v,a,choice,w,err)
% WFPT_ROBUST
%
% Numerically stable log-density of the Wiener first-passage time
% distribution.
%
% INPUTS
%   t      - Decision time in seconds.
%   v      - Drift rate.
%   a      - Boundary separation.
%   choice - 1 = lower boundary, 2 = upper boundary (default = 2).
%   w      - Relative starting point z/a (default = 0.5).
%   err    - Error tolerance (default = 1e-6).
%
% OUTPUT
%   logP   - Log probability density.


if nargin < 4
    choice = 2;
end

if nargin < 5
    w = 0.5;
end

if nargin < 6
    err = 1e-6;
end


% Reflection for lower boundary
if choice == 1
    v = -v;
    w = 1-w;
end

logP = zeros(size(t));


for i = 1:length(t)

    if t(i) <= 0 || isnan(t(i))
        logP(i) = -inf;
        continue
    end

    tt = t(i)/(a^2);

    % Girsanov term
    logGirsanov = ...
        -v*a*w - (v^2)*t(i)/2 - 2*log(a);


    %% Number of terms for large-t series

    if pi*tt*err < 1

        kl = sqrt( ...
            -2*log(pi*tt*err)/(pi^2*tt));

        kl = max( ...
            kl, ...
            1/(pi*sqrt(tt)));

    else
        kl = 1/(pi*sqrt(tt));
    end


    %% Number of terms for small-t series

    if 2*sqrt(2*pi*tt)*err < 1

        ks = 2 + sqrt( ...
            -2*tt*log(2*sqrt(2*pi*tt)*err));

        ks = max(ks,sqrt(tt)+1);

    else
        ks = 2;
    end


    %% Evaluate appropriate series

    if ks < kl

        % Small-t series
        K = ceil(ks);
        logSum = -inf;

        for k = -floor((K-1)/2):ceil((K-1)/2)

            x = w + 2*k;

            if x ~= 0

                term = ...
                    log(abs(x)) - ...
                    (x^2)/(2*tt);

                logSum = logaddexp(logSum,term);

            end
        end

        logSeries = ...
            logSum - 0.5*log(2*pi*tt^3);


    else

        % Large-t series
        K = ceil(kl);
        logSum = -inf;

        for k = 1:K

            s = sin(k*pi*w);

            if s > 0

                term = ...
                    log(k) + ...
                    log(s) - ...
                    (k^2)*(pi^2)*tt/2;

                logSum = logaddexp(logSum,term);

            end
        end

        logSeries = logSum + log(pi);

    end

    logP(i) = logSeries + logGirsanov;

end

end


%% ========================================================================
%  LOG-SUM-EXP HELPER
%  ========================================================================
function c = logaddexp(a,b)
% LOGADDEXP
%
% Numerically stable calculation of log(exp(a) + exp(b)).

if a == -inf
    c = b;

elseif b == -inf
    c = a;

else
    c = max(a,b) + ...
        log1p(exp(min(a,b)-max(a,b)));
end

end