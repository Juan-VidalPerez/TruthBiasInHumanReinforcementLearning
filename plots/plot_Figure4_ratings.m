function out = plot_Figure4_ratings(data, parameters)
% PLOT_FIGURE4_RATINGS
%
% Generates the behavioural plots used for Figure 4:
%
%   b) Raw explicit reward-probability ratings
%   c) Explicit Truth Probability (ETP)
%   d) Relationship between explicit and RL truth bias
%
% INPUTS
%   data       - Study 2 behavioural data. Ratings must be stored in:
%
%                   data{ss,3}.ratings
%
%                as a 4 x 2 matrix:
%                   rows    = sources 1-4
%                   column 1 = non-reward feedback
%                   column 2 = reward feedback
%
%   parameters - Fitted parameters from the Study 2
%                truth x certainty CA model:
%
%                   par_truthxcertainty_s2
%
%                The first four columns must contain the source-specific
%                CA parameters ordered:
%                   1-star, 2-star, 3-star, 4-star
%
%                CA parameters are assumed to already use the
%                implied-feedback convention.
%
% OUTPUT
%   out.raw_ratings
%       N x 4 x 2 raw reward-probability ratings.
%
%   out.ETP_by_valence
%       N x 4 x 2 implied truth probabilities.
%
%   out.ETP
%       N x 4 ETP averaged across feedback valence.
%
%   out.explicit_TB
%       Participant-level truth bias in explicit ratings.
%
%   out.CA_TB
%       Participant-level truth bias in CA.
%
%   out.rho
%   out.p
%       Spearman correlation between explicit and CA truth bias.


%% Settings

colors = [255 127   0;
          253 191 111;
          166 206 227;
           55 126 184] / 255;

source_labels = {'0','1/3','2/3','1'};

nSub = size(data,1);


%% ========================================================================
%  EXTRACT AND TRANSFORM RATINGS
%  ========================================================================

raw_ratings = nan(nSub,4,2);
ETP_by_valence = nan(nSub,4,2);


for ss = 1:nSub

    ratings = data{ss,3}.ratings;

    if ~isequal(size(ratings),[4 2])
        error( ...
            'Participant %d ratings must be a 4 x 2 matrix.', ...
            ss);
    end

    % ---------------------------------------------------------------
    % Raw ratings:
    % P(true latent outcome = reward)
    % ---------------------------------------------------------------

    raw_ratings(ss,:,:) = ratings;


    % ---------------------------------------------------------------
    % Convert to probability that the literal feedback was correct
    %
    % For non-reward feedback:
    % P(feedback correct) = 100 - P(reward)
    % ---------------------------------------------------------------

    implied = ratings;
    implied(:,1) = 100 - implied(:,1);


    % ---------------------------------------------------------------
    % Flip feedback from predominantly untruthful sources.
    %
    % This places all sources in the same implied-feedback coordinate:
    % high values = high probability that the source-implied outcome
    % was actually true.
    % ---------------------------------------------------------------

    implied(1:2,:) = 100 - implied(1:2,:);

    ETP_by_valence(ss,:,:) = implied;

end


% Explicit Truth Probability averaged across feedback valence
ETP = mean(ETP_by_valence,3);


%% ========================================================================
%  TRUTH-BIAS MEASURES
%  ========================================================================

% Explicit truth bias:
%
%   [(3-star - 2-star) + (4-star - 1-star)] / 2
%
% equivalent to:
%
%   (ETP3 + ETP4 - ETP2 - ETP1) / 2

explicit_TB = ...
    (ETP(:,3) + ETP(:,4) - ETP(:,2) - ETP(:,1)) / 2;


% CA truth bias from truth x certainty model.
%
% CA parameters already use implied-feedback coordinates, so no further
% sign flipping is required.

if size(parameters,1) ~= nSub || size(parameters,2) < 4
    error( ...
        ['parameters must have one row per participant and at least ' ...
         'four source-specific CA columns.']);
end

CA = parameters(:,1:4);

CA_TB = ...
    (CA(:,3) + CA(:,4) - CA(:,2) - CA(:,1)) / 2;


%% ========================================================================
%  FIGURE 4b: RAW EXPLICIT RATINGS
%  ========================================================================

figure

% Non-reward feedback
subplot(1,2,1)

plot_rating_summary( ...
    squeeze(raw_ratings(:,:,1)), ...
    colors, ...
    source_labels);

hold on

% Bayesian ground truth given negative feedback
plot( ...
    (1:4)+0.20, ...
    [100 67 33 0], ...
    'o', ...
    'Color','k', ...
    'MarkerFaceColor','k', ...
    'MarkerSize',4);

xlabel('Source credibility')
ylabel('Rated P(reward)')
title('Non-reward feedback')
ylim([0 100])


% Reward feedback
subplot(1,2,2)

plot_rating_summary( ...
    squeeze(raw_ratings(:,:,2)), ...
    colors, ...
    source_labels);

hold on

% Bayesian ground truth given positive feedback
plot( ...
    (1:4)+0.20, ...
    [0 33 67 100], ...
    'o', ...
    'Color','k', ...
    'MarkerFaceColor','k', ...
    'MarkerSize',4);

xlabel('Source credibility')
ylabel('')
title('Reward feedback')
ylim([0 100])


%% ========================================================================
%  FIGURE 4c: EXPLICIT TRUTH PROBABILITY
%  ========================================================================

figure

plot_2by2( ...
    ETP, ...
    [2.1 1.1 0.9 1.9], ...
    {'Uncertain','Certain'}, ...
    1, ...
    colors, ...
    'Explicit truth probability (ETP)');

xlabel('Source certainty')
ylim([40 100])


%% ========================================================================
%  FIGURE 4d: EXPLICIT TB vs RL TB
%  ========================================================================

figure

[rho, p] = plot_truthbias_correlation( ...
    explicit_TB, ...
    CA_TB);

xlabel('Explicit truth bias')
ylabel('CA truth bias')


%% Outputs

out.raw_ratings = raw_ratings;
out.ETP_by_valence = ETP_by_valence;
out.ETP = ETP;

out.explicit_TB = explicit_TB;
out.CA_TB = CA_TB;

out.rho = rho;
out.p = p;

end


%% ========================================================================
%  RATING SUMMARY
%  ========================================================================
function plot_rating_summary(ratings, colors, labels)
% PLOT_RATING_SUMMARY
%
% Plots participant mean +/- SEM for the four sources.
%
% INPUT
%   ratings - N x 4 matrix.

nSub = size(ratings,1);

for source = 1:4

    m = mean(ratings(:,source));
    sem = std(ratings(:,source)) / sqrt(nSub);

    bar( ...
        source, ...
        m, ...
        'FaceColor',colors(source,:), ...
        'EdgeColor','black');

    hold on

    errorbar( ...
        source, ...
        m, ...
        sem, ...
        'k', ...
        'LineStyle','none', ...
        'LineWidth',1, ...
        'CapSize',8);

end

xticks(1:4)
xticklabels(labels)
xlim([0.5 4.5])

end


%% ========================================================================
%  TRUTH-BIAS CORRELATION
%  ========================================================================
function [rho, p] = plot_truthbias_correlation(x, y)
% PLOT_TRUTHBIAS_CORRELATION
%
% Plots the explicit-vs-CA truth-bias relationship.
%
% The inferential statistic is Spearman's rho, matching the manuscript.
% The black line and shaded interval show the OLS regression fit and its
% 95% confidence interval for visualization.


valid = ~isnan(x) & ~isnan(y);

x = x(valid);
y = y(valid);


%% Spearman correlation

[rho, p] = corr( ...
    x, y, ...
    'Type','Spearman');


%% Participant data

scatter( ...
    x, y, ...
    24, [0.5 0.5 0.5],...
    'filled', ...
    'MarkerFaceAlpha',0.5,...
    'MarkerEdgeAlpha',1);

hold on


%% Linear regression line + 95% CI

mdl = fitlm(x,y);

xFit = linspace(min(x),max(x),200)';
[yFit,yCI] = predict(mdl,xFit);


fill( ...
    [xFit; flipud(xFit)], ...
    [yCI(:,1); flipud(yCI(:,2))], ...
    [0.7 0.7 0.7], ...
    'FaceAlpha',0.35, ...
    'EdgeColor','none');

plot( ...
    xFit, ...
    yFit, ...
    'k-', ...
    'LineWidth',2);


%% Statistic

text( ...
    0.05,0.95, ...
    sprintf('\\rho = %.2f, p = %.3f',rho,p), ...
    'Units','normalized', ...
    'VerticalAlignment','top');

end