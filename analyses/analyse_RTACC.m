function [mdl_rt, mdl_acc, out] = analyse_RTACC(data, study, analysis, make_plots)
% ANALYSE_RTACC
%
% Computes source-specific reaction time and choice accuracy and fits the
% mixed-effects models reported in the manuscript and SI.
%
% INPUTS
%   data        - Behavioural data:
%                     Study 1: data_s1
%                     Study 2: data_s2
%
%   study       - Study number:
%                     1 = Study 1
%                     2 = Study 2
%
%   analysis    - Model specification:
%
%                     'main'  = main-text models (default)
%                     'full'  = certainty-inclusive SI models
%
%   make_plots  - Whether to generate source-level RT/accuracy plots:
%                     true  = plot (default)
%                     false = do not plot
%
% OUTPUTS
%   mdl_rt      - Linear mixed-effects model for median RT.
%
%   mdl_acc     - Binomial mixed-effects model for choice accuracy.
%
%   out.rt      - Participant-level median RT:
%
%                     Study 1: N x 4
%                     Study 2: N x 4 x 2
%
%   out.acc     - Participant-level mean accuracy:
%
%                     Study 1: N x 4
%                     Study 2: N x 4 x 2
%
%   out.successes
%   out.opportunities
%                - Counts used in the binomial accuracy model.
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
%   BASE_RATE (Study 2):
%       +0.5 = Truth-Prevalent (TP)
%       -0.5 = Lie-Prevalent   (LP)
%
% MODELS
%
%   Study 1, main:
%       RT       ~ TRUE + (1|SS)
%       ACCURACY ~ TRUE + (TRUE + 1|SS)
%
%   Study 1, full/SI:
%       RT       ~ TRUE*CERTAIN + (1|SS)
%       ACCURACY ~ TRUE*CERTAIN + (TRUE*CERTAIN + 1|SS)
%
%   Study 2, main:
%       RT       ~ TRUE*BASE_RATE + (1|SS)
%       ACCURACY ~ TRUE*BASE_RATE
%                  + (TRUE*BASE_RATE + 1|SS)
%
%   Study 2, full/SI:
%       RT       ~ TRUE*CERTAIN*BASE_RATE + (1|SS)
%       ACCURACY ~ TRUE*CERTAIN*BASE_RATE
%                  + (TRUE*CERTAIN*BASE_RATE + 1|SS)


%% Defaults

if nargin < 3 || isempty(analysis)
    analysis = 'main';
end

if nargin < 4
    make_plots = true;
end

if ~ismember(study,[1 2])
    error('study must be 1 or 2.')
end

if ~ismember(analysis,{'main','full'})
    error('analysis must be ''main'' or ''full''.')
end


%% Settings

colors = [255 127   0;
          253 191 111;
          166 206 227;
           55 126 184] / 255;

cred = sort(unique(data{1,3}.cred(:)))';

if length(cred) ~= 4
    error('Expected four feedback-source credibility levels.')
end


%% ========================================================================
%  EXTRACT RT AND ACCURACY
%  ========================================================================

nSub = size(data,1);

if study == 1

    out.rt            = nan(nSub,4);
    out.acc           = nan(nSub,4);
    out.successes     = zeros(nSub,4);
    out.opportunities = zeros(nSub,4);

    for ss = 1:nSub

        d = data{ss,3};

        for source = 1:4

            valid = ...
                d.cred == cred(source) & ...
                d.pick ~= 0;

            % Median RT for each participant x source
            out.rt(ss,source) = ...
                median(d.response_time(valid),'all','omitnan');

            % Accuracy counts
            out.successes(ss,source) = ...
                sum(d.accuracy(valid) == 1,'all','omitnan');

            out.opportunities(ss,source) = ...
                sum(valid,'all','omitnan');

            out.acc(ss,source) = ...
                out.successes(ss,source) / ...
                out.opportunities(ss,source);

        end
    end


else  % Study 2

    out.rt            = nan(nSub,4,2);
    out.acc           = nan(nSub,4,2);
    out.successes     = zeros(nSub,4,2);
    out.opportunities = zeros(nSub,4,2);

    for ss = 1:nSub

        d = data{ss,3};

        for condition = 1:2
            for source = 1:4

                valid = ...
                    d.cred == cred(source) & ...
                    d.condition == condition & ...
                    d.pick ~= 0;

                % Median RT for participant x source x base-rate condition
                out.rt(ss,source,condition) = ...
                    median(d.response_time(valid),'all','omitnan');

                % Accuracy counts
                out.successes(ss,source,condition) = ...
                    sum(d.accuracy(valid) == 1,'all','omitnan');

                out.opportunities(ss,source,condition) = ...
                    sum(valid,'all','omitnan');

                out.acc(ss,source,condition) = ...
                    out.successes(ss,source,condition) / ...
                    out.opportunities(ss,source,condition);

            end
        end
    end

end


%% ========================================================================
%  FIT MIXED-EFFECTS MODELS
%  ========================================================================

mdl_rt = fit_RT_model(out.rt, study, analysis);

mdl_acc = fit_accuracy_model( ...
    out.successes, ...
    out.opportunities, ...
    study, ...
    analysis);


%% ========================================================================
%  PLOTS
%  ========================================================================

if make_plots
    plot_RTACC_summary(out, study, analysis, colors);
end

end


%% ========================================================================
%  REACTION-TIME MODEL
%  ========================================================================
function mdl = fit_RT_model(rt, study, analysis)
% FIT_RT_MODEL
%
% Fits the source-level median RT mixed-effects model.


nSub = size(rt,1);


if study == 1

    % Order:
    % participant 1: sources 1,2,3,4
    % participant 2: sources 1,2,3,4
    % ...

    RT = rt';
    RT = RT(:);

    TRUE = repmat( ...
        [-0.5; -0.5; 0.5; 0.5], ...
        nSub,1);

    CERTAIN = repmat( ...
        [0.5; -0.5; -0.5; 0.5], ...
        nSub,1);

    SS = repelem((1:nSub)',4);

    tbl = table( ...
        RT, TRUE, CERTAIN, SS, ...
        'VariableNames', ...
        {'RT','TRUE','CERTAIN','SS'});


    switch analysis

        case 'main'

            formula = ...
                'RT ~ TRUE + (1|SS)';

        case 'full'

            formula = ...
                'RT ~ TRUE*CERTAIN + (1|SS)';

    end


else  % Study 2

    % Convert N x source x condition to:
    %
    %   source 1-4 TP,
    %   source 1-4 LP,
    %   for each participant.

    tmp = permute(rt,[2 3 1]);
    RT = tmp(:);

    TRUE = repmat( ...
        [-0.5; -0.5; 0.5; 0.5; ...
         -0.5; -0.5; 0.5; 0.5], ...
        nSub,1);

    CERTAIN = repmat( ...
        [0.5; -0.5; -0.5; 0.5; ...
         0.5; -0.5; -0.5; 0.5], ...
        nSub,1);

    % condition 1 = TP; condition 2 = LP
    BASE_RATE = repmat( ...
        [0.5; 0.5; 0.5; 0.5; ...
        -0.5;-0.5;-0.5;-0.5], ...
        nSub,1);

    SS = repelem((1:nSub)',8);

    tbl = table( ...
        RT, TRUE, CERTAIN, BASE_RATE, SS, ...
        'VariableNames', ...
        {'RT','TRUE','CERTAIN','BASE_RATE','SS'});


    switch analysis

        case 'main'

            formula = ...
                'RT ~ TRUE*BASE_RATE + (1|SS)';

        case 'full'

            formula = ...
                'RT ~ TRUE*CERTAIN*BASE_RATE + (1|SS)';

    end

end


% Remove missing source-level medians if present
tbl = tbl(~isnan(tbl.RT),:);

mdl = fitglme( ...
    tbl, ...
    formula, ...
    'Distribution','normal', ...
    'FitMethod','Laplace', ...
    'CheckHessian',true);

end


%% ========================================================================
%  ACCURACY MODEL
%  ========================================================================
function mdl = fit_accuracy_model(successes, opportunities, study, analysis)
% FIT_ACCURACY_MODEL
%
% Fits the grouped-binomial mixed-effects model for choice accuracy.


nSub = size(successes,1);


if study == 1

    ACCURACY = successes';
    ACCURACY = ACCURACY(:);

    N = opportunities';
    N = N(:);

    TRUE = repmat( ...
        [-0.5; -0.5; 0.5; 0.5], ...
        nSub,1);

    CERTAIN = repmat( ...
        [0.5; -0.5; -0.5; 0.5], ...
        nSub,1);

    SS = repelem((1:nSub)',4);

    tbl = table( ...
        ACCURACY, TRUE, CERTAIN, SS, ...
        'VariableNames', ...
        {'ACCURACY','TRUE','CERTAIN','SS'});


    switch analysis

        case 'main'

            formula = ...
                'ACCURACY ~ TRUE + (TRUE + 1|SS)';

        case 'full'

            formula = ...
                ['ACCURACY ~ TRUE*CERTAIN + ' ...
                 '(TRUE*CERTAIN + 1|SS)'];

    end


else  % Study 2

    tmp = permute(successes,[2 3 1]);
    ACCURACY = tmp(:);

    tmp = permute(opportunities,[2 3 1]);
    N = tmp(:);

    TRUE = repmat( ...
        [-0.5; -0.5; 0.5; 0.5; ...
         -0.5; -0.5; 0.5; 0.5], ...
        nSub,1);

    CERTAIN = repmat( ...
        [0.5; -0.5; -0.5; 0.5; ...
         0.5; -0.5; -0.5; 0.5], ...
        nSub,1);

    BASE_RATE = repmat( ...
        [0.5; 0.5; 0.5; 0.5; ...
        -0.5;-0.5;-0.5;-0.5], ...
        nSub,1);

    SS = repelem((1:nSub)',8);

    tbl = table( ...
        ACCURACY, TRUE, CERTAIN, BASE_RATE, SS, ...
        'VariableNames', ...
        {'ACCURACY','TRUE','CERTAIN','BASE_RATE','SS'});


    switch analysis

        case 'main'

            formula = ...
                ['ACCURACY ~ TRUE*BASE_RATE + ' ...
                 '(TRUE*BASE_RATE + 1|SS)'];

        case 'full'

            formula = ...
                ['ACCURACY ~ TRUE*CERTAIN*BASE_RATE + ' ...
                 '(TRUE*CERTAIN*BASE_RATE + 1|SS)'];

    end

end


%% Remove cells with no valid choices

keep = N > 0;

tbl = tbl(keep,:);
N = N(keep);


%% Fit grouped-binomial model

mdl = fitglme( ...
    tbl, ...
    formula, ...
    'Distribution','Binomial', ...
    'BinomialSize',N, ...
    'FitMethod','Laplace', ...
    'CheckHessian',true);

end


%% ========================================================================
%  PLOT RT AND ACCURACY
%  ========================================================================
%% ========================================================================
%  PLOT RT AND ACCURACY
%  ========================================================================
function plot_RTACC_summary(out, study, analysis, colors)
% PLOT_RTACC_SUMMARY
%
% Main analyses:
%   Plot only the effect of source truthfulness, averaging across
%   certainty levels, as shown in the main manuscript.
%
% Full/SI analyses:
%   Plot all four sources separately to show Truth x Certainty effects.


%% Plot settings

ylims_rt  = [740 860];
ylims_acc = [0.62 0.67];

% Average colors for untruthful and truthful sources
truth_colors = [ ...
    mean(colors(1:2,:),1); ...
    mean(colors(3:4,:),1)];


%% ========================================================================
%  MAIN-TEXT PLOTS: TRUTH EFFECT COLLAPSED ACROSS CERTAINTY
%  ========================================================================

if strcmp(analysis,'main')

    if study == 1

        % ---------------------------------------------------------------
        % Study 1: 50% truthful environment
        % ---------------------------------------------------------------

        rt_truth = [ ...
            mean(out.rt(:,1:2),2,'omitnan'), ...
            mean(out.rt(:,3:4),2,'omitnan')];

        acc_truth = [ ...
            mean(out.acc(:,1:2),2,'omitnan'), ...
            mean(out.acc(:,3:4),2,'omitnan')];


        %% Reaction time

        figure

        plot_truth_bars( ...
            rt_truth, ...
            truth_colors);

        ylim(ylims_rt)
        ylabel('Reaction time (ms)')
        xlabel('Source truthfulness')
        title('Study 1')


        %% Accuracy

        figure

        plot_truth_bars( ...
            acc_truth, ...
            truth_colors);

        ylim(ylims_acc)
        ylabel('Accuracy rate')
        xlabel('Source truthfulness')
        title('Study 1')


    else

        % ---------------------------------------------------------------
        % Study 2: TP and LP environments
        % ---------------------------------------------------------------

        rt_TP = [ ...
            mean(out.rt(:,1:2,1),2,'omitnan'), ...
            mean(out.rt(:,3:4,1),2,'omitnan')];

        rt_LP = [ ...
            mean(out.rt(:,1:2,2),2,'omitnan'), ...
            mean(out.rt(:,3:4,2),2,'omitnan')];

        acc_TP = [ ...
            mean(out.acc(:,1:2,1),2,'omitnan'), ...
            mean(out.acc(:,3:4,1),2,'omitnan')];

        acc_LP = [ ...
            mean(out.acc(:,1:2,2),2,'omitnan'), ...
            mean(out.acc(:,3:4,2),2,'omitnan')];


        %% Reaction time

        figure

        subplot(1,2,1)

        plot_truth_bars( ...
            rt_TP, ...
            truth_colors);

        ylim(ylims_rt)
        ylabel('Reaction time (ms)')
        xlabel('Source truthfulness')
        title('Truth-prevalent')


        subplot(1,2,2)

        plot_truth_bars( ...
            rt_LP, ...
            truth_colors);

        ylim(ylims_rt)
        ylabel('')
        yticklabels({})
        xlabel('Source truthfulness')
        title('Lie-prevalent')


        %% Accuracy

        figure

        subplot(1,2,1)

        plot_truth_bars( ...
            acc_TP, ...
            truth_colors);

        ylim(ylims_acc)
        ylabel('Accuracy rate')
        xlabel('Source truthfulness')
        title('Truth-prevalent')


        subplot(1,2,2)

        plot_truth_bars( ...
            acc_LP, ...
            truth_colors);

        ylim(ylims_acc)
        ylabel('')
        yticklabels({})
        xlabel('Source truthfulness')
        title('Lie-prevalent')

    end


%% ========================================================================
%  FULL / SI PLOTS: SHOW ALL FOUR SOURCES
%  ========================================================================

else

    source_labels = {'1/3','2/3','0','1'};

    if study == 1

        %% Reaction time

        figure

        plot_source_bars(out.rt, colors);

        ylim(ylims_rt)
        ylabel('Reaction time (ms)')
        xlabel('Source credibility')
        xticklabels(source_labels)


        %% Accuracy

        figure

        plot_source_bars(out.acc, colors);

        ylim(ylims_acc)
        ylabel('Accuracy rate')
        xlabel('Source credibility')
        xticklabels(source_labels)


    else

        %% Reaction time

        figure

        subplot(1,2,1)

        plot_source_bars( ...
            out.rt(:,:,1), ...
            colors);

        ylim(ylims_rt)
        ylabel('Reaction time (ms)')
        xlabel('Source credibility')
        xticklabels(source_labels)
        title('Truth-prevalent')


        subplot(1,2,2)

        plot_source_bars( ...
            out.rt(:,:,2), ...
            colors);

        ylim(ylims_rt)
        ylabel('')
        yticklabels({})
        xlabel('Source credibility')
        xticklabels(source_labels)
        title('Lie-prevalent')


        %% Accuracy

        figure

        subplot(1,2,1)

        plot_source_bars( ...
            out.acc(:,:,1), ...
            colors);

        ylim(ylims_acc)
        ylabel('Accuracy rate')
        xlabel('Source credibility')
        xticklabels(source_labels)
        title('Truth-prevalent')


        subplot(1,2,2)

        plot_source_bars( ...
            out.acc(:,:,2), ...
            colors);

        ylim(ylims_acc)
        ylabel('')
        yticklabels({})
        xlabel('Source credibility')
        xticklabels(source_labels)
        title('Lie-prevalent')

    end

end

end


%% ========================================================================
%  TRUTH-EFFECT BAR PLOT
%  ========================================================================
function plot_truth_bars(data, colors)
% PLOT_TRUTH_BARS
%
% Plots participant-level values averaged across source certainty.
%
% INPUT
%   data(:,1) = average across untruthful sources (1-/2-star)
%   data(:,2) = average across truthful sources   (3-/4-star)


for group = 1:2

    values = data(:,group);

    m = mean(values,'omitnan');

    sem = ...
        std(values,'omitnan') / ...
        sqrt(sum(~isnan(values)));


    bar( ...
        group, ...
        m, ...
        'FaceColor',colors(group,:), ...
        'EdgeColor','black', ...
        'LineWidth',1.5);

    hold on


    errorbar( ...
        group, ...
        m, ...
        sem, ...
        'Color','k', ...
        'LineStyle','none', ...
        'LineWidth',1.5, ...
        'CapSize',0);

end

xlim([0.5 2.5])

xticks([1 2])
xticklabels({'Untruthful','Truthful'})

box off

end


%% ========================================================================
%  FOUR-SOURCE BAR PLOT
%  ========================================================================
function plot_source_bars(data, colors)
% PLOT_SOURCE_BARS
%
% Plots all four feedback sources for the full/SI analyses.
%
% INPUT
%   data - N x 4 values ordered:
%              1-star, 2-star, 3-star, 4-star
%
% DISPLAY ORDER
%   x = 1 : 2-star
%   x = 2 : 3-star
%   x = 4 : 1-star
%   x = 5 : 4-star
%
% This groups uncertain sources together and certain sources together.


x = [1 2 4 5];

source_order = [2 3 1 4];


for ii = 1:4

    source = source_order(ii);

    values = data(:,source);

    m = mean(values,'omitnan');

    sem = ...
        std(values,'omitnan') / ...
        sqrt(sum(~isnan(values)));


    bar( ...
        x(ii), ...
        m, ...
        'FaceColor',colors(source,:), ...
        'EdgeColor','black', ...
        'LineWidth',1.5);

    hold on


    errorbar( ...
        x(ii), ...
        m, ...
        sem, ...
        'Color','k', ...
        'LineStyle','none', ...
        'LineWidth',1.5, ...
        'CapSize',0);

end

xlim([0 6])

xticks(x)

box off

end