function mdl = analyse_CA_parameters(parameters, study, data)
% ANALYSE_CA_PARAMETERS
%
% Fits the mixed-effects models reported for fitted Credit-Assignment (CA)
% parameters.
%
% INPUTS
%   parameters - Fitted CA parameter matrix.
%
%                Study 1:
%                   par_truthxcertainty_s1       [N x 7]
%
%                Study 2:
%                   par_truthxcertaintyxbr_s2    [N x 11]
%
%                For the explicit-TB analysis:
%                   par_truthxcertainty_s2       [N x 7]
%
%   study      - 1 or 2.
%
%   data       - Behavioural data. Required only for 'explicit_tb',
%                because explicit truth bias is calculated from ratings.
%
% OUTPUT
%   mdl        - Fitted linear mixed-effects model.
%
% CODING
%   TRUE:
%       -0.5 = untruthful source (1-/2-star)
%       +0.5 = truthful source   (3-/4-star)
%
%   CERTAIN:
%       -0.5 = uncertain source (2-/3-star)
%       +0.5 = certain source   (1-/4-star)
%
%   BASE_RATE:
%       +0.5 = Truth-Prevalent
%       -0.5 = Lie-Prevalent
%
% NOTES
%   CA parameters are assumed to already use the implied-feedback
%   convention. No sign flipping is performed here.






%% ===================================================================
%  CA PARAMETER ANALYSES
%  ===================================================================


    switch study

        % -----------------------------------------------------------
        % Study 1: Truth x Certainty
        % -----------------------------------------------------------
        case 1

            if size(parameters,2) < 4
                error('Study 1 CA analysis requires at least 4 CA parameters.')
            end

            CA = parameters(:,1:4);

            [CA, TRUE, CERTAIN, SS] = ...
                expand_four_sources(CA);

            tbl = table( ...
                CA, TRUE, CERTAIN, SS, ...
                'VariableNames', ...
                {'CA','TRUE','CERTAIN','SS'});

            mdl = fitglme( ...
                tbl, ...
                'CA ~ TRUE*CERTAIN + (TRUE*CERTAIN + 1|SS)', ...
                'Distribution','normal', ...
                'FitMethod','Laplace', ...
                'CheckHessian',true);


        % -----------------------------------------------------------
        % Study 2: Truth x Certainty x Base Rate
        % -----------------------------------------------------------
        case 2

            if size(parameters,2) < 8
                error('Study 2 CA analysis requires at least 8 CA parameters.')
            end

            % First four = TP; second four = LP
            CA = parameters(:,1:8);

            nSub = size(CA,1);

            CA = CA';

            TRUE = repmat( ...
                [0 0 1 1 0 0 1 1], ...
                1,nSub)' - 0.5;

            CERTAIN = repmat( ...
                [1 0 0 1 1 0 0 1], ...
                1,nSub)' - 0.5;

            BASE_RATE = repmat( ...
                [0.5 0.5 0.5 0.5 ...
                -0.5 -0.5 -0.5 -0.5], ...
                1,nSub)';

            SS = repelem((1:nSub)',8);

            tbl = table( ...
                CA(:), TRUE, CERTAIN, BASE_RATE, SS, ...
                'VariableNames', ...
                {'CA','TRUE','CERTAIN','BASE_RATE','SS'});

            mdl = fitglme( ...
                tbl, ...
                ['CA ~ TRUE*(CERTAIN + BASE_RATE) + ' ...
                 '(TRUE*(CERTAIN + BASE_RATE) + 1|SS)'], ...
                'Distribution','normal', ...
                'FitMethod','Laplace', ...
                'CheckHessian',true);


        otherwise
            error('study must be 1 or 2.')
    end


    

end


%% ========================================================================
%  FOUR-SOURCE DATA PREPARATION
%  ========================================================================
function [Y, TRUE, CERTAIN, SS] = expand_four_sources(Y)

nSub = size(Y,1);

Y = Y';

TRUE = repmat( ...
    [0 0 1 1], ...
    1,nSub)' - 0.5;

CERTAIN = repmat( ...
    [1 0 0 1], ...
    1,nSub)' - 0.5;

SS = repelem((1:nSub)',4);

Y = Y(:);

end


%% ========================================================================
%  EXPLICIT TRUTH PROBABILITY
%  ========================================================================
function ETP = calculate_ETP(data)
% CALCULATE_ETP
%
% Returns one explicit truth probability per participant x source.
%
% ratings is assumed to be 4 sources x 2 feedback-valence conditions.

nSub = size(data,1);
ETP = nan(nSub,4);

for ss = 1:nSub

    ratings = data{ss,3}.ratings;

    % Convert ratings to implied true-outcome probabilities using the same
    % transformation as the original analysis.
    ratings(:,1) = 100 - ratings(:,1);
    ratings(1:2,:) = 100 - ratings(1:2,:);

    ETP(ss,:) = mean(ratings,2)';

end

end