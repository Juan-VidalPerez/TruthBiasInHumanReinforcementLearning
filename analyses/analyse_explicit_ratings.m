function [mdl, ETP] = analyse_explicit_ratings(data, analysis)
% ANALYSE_EXPLICIT_RATINGS
%
% Fits the mixed-effects models reported for the Study 2 explicit-rating
% task.
%
% INPUTS
%   data     - Study 2 behavioural data. Explicit ratings are expected in:
%
%                  data{ss,3}.ratings
%
%              with 4 sources x 2 feedback-valence conditions.
%
%   analysis - Analysis to run:
%
%                  'main'           ETP ~ TRUE*CERTAIN
%                  'preregistered'  ETP ~ TRUE*CERTAIN*VALENCE
%
% OUTPUTS
%   mdl      - Fitted linear mixed-effects model.
%
%   ETP      - nParticipant x 4 matrix of explicit truth probabilities,
%              averaged across feedback valence.
%
% DEFINITION
%   Ratings are first transformed into the probability of the outcome
%   implied to be true by each source. This includes sign inversion for
%   feedback from the predominantly untruthful sources.
%
%   ETP is then the average implied truth probability across positive and
%   negative feedback for each source.


if nargin < 2
    analysis = 'main';
end

nSub = size(data,1);

ETP = nan(nSub,4);


switch analysis

    %% ===================================================================
    %  MAIN-TEXT ETP ANALYSIS
    %  ===================================================================
    case 'main'

        for ss = 1:nSub

            ratings = transform_ratings( ...
                data{ss,3}.ratings);

            ETP(ss,:) = mean(ratings,2)';

        end

        [SCORES, TRUE, CERTAIN, SS] = ...
            expand_four_sources(ETP);

        tbl = table( ...
            SCORES - 50, TRUE, CERTAIN, SS, ...
            'VariableNames', ...
            {'ETP','TRUE','CERTAIN','SS'});

        mdl = fitglme( ...
            tbl, ...
            'ETP ~ TRUE*CERTAIN + (TRUE*CERTAIN + 1|SS)', ...
            'Distribution','normal', ...
            'FitMethod','Laplace', ...
            'CheckHessian',true);


    %% ===================================================================
    %  PREREGISTERED VALENCE-INCLUSIVE ANALYSIS
    %  ===================================================================
    case 'preregistered'

        ratings_all = nan(nSub,4,2);

        for ss = 1:nSub

            ratings_all(ss,:,:) = ...
                transform_ratings( ...
                    data{ss,3}.ratings);

            ETP(ss,:) = ...
                mean(ratings_all(ss,:,:),3);

        end

        % Order within participant:
        % source 1:4 for valence 1, then source 1:4 for valence 2
        SCORES = permute(ratings_all,[2 3 1]);
        SCORES = SCORES(:) - 50;

        TRUE = repmat( ...
            [0 0 1 1 0 0 1 1], ...
            1,nSub)' - 0.5;

        CERTAIN = repmat( ...
            [1 0 0 1 1 0 0 1], ...
            1,nSub)' - 0.5;

        VALENCE = repmat( ...
            [-0.5 -0.5 -0.5 -0.5 ...
              0.5  0.5  0.5  0.5], ...
            1,nSub)';

        SS = repelem((1:nSub)',8);

        tbl = table( ...
            SCORES, TRUE, CERTAIN, VALENCE, SS, ...
            'VariableNames', ...
            {'ETP','TRUE','CERTAIN','VALENCE','SS'});

        mdl = fitglme( ...
            tbl, ...
            ['ETP ~ TRUE*CERTAIN*VALENCE + ' ...
             '(TRUE*CERTAIN*VALENCE + 1|SS)'], ...
            'Distribution','normal', ...
            'FitMethod','Laplace', ...
            'CheckHessian',true);


    otherwise
        error( ...
            'analysis must be ''main'' or ''preregistered''.')

end

end


%% ========================================================================
%  TRANSFORM RATINGS INTO IMPLIED TRUTH PROBABILITY
%  ========================================================================
function ratings = transform_ratings(ratings)
% TRANSFORM_RATINGS
%
% Converts raw reward-probability ratings into probability of the outcome
% implied to be true by each source.
%
% This reproduces the transformation used in the original analysis.

% Convert first feedback-valence column
ratings(:,1) = 100 - ratings(:,1);

% Reverse ratings for the two predominantly untruthful sources
ratings(1:2,:) = 100 - ratings(1:2,:);

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