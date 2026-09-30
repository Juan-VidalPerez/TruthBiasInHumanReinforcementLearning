function [mdl, out] = analyse_ModelAgnostic(data, study)
% ANALYSE_MODELAGNOSTIC
%
% Runs the model-agnostic choice-repetition analysis and generates the
% corresponding plots using the generic functions in /plots.
%
% INPUTS
%   data  - Behavioural dataset loaded from:
%               Study 1: data_s1.mat
%               Study 2: data_s2.mat
%
%           Participant behavioural data are stored in data{i,2} and must
%           contain:
%               .cred       - feedback-source credibility
%               .pick       - participant choice
%               .feedback   - source feedback (0/1)
%               .accuracy   - whether the chosen bandit was better/worse
%
%           Study 2 additionally requires:
%               .condition  - base-rate condition
%                             1 = Truth-Prevalent (TP)
%                             2 = Lie-Prevalent (LP)
%
%   study - Study number:
%               1 = Study 1
%               2 = Study 2
%
% OUTPUTS
%   mdl   - GeneralizedLinearMixedModel returned by FITGLME.
%
%   out   - Structure containing participant-level plotting quantities:
%
%           Study 1:
%               out.p_repeat
%               out.p_repeat_plot
%               out.feedback_effect
%
%           Study 2:
%               out.p_repeat{1}          - TP blocks
%               out.p_repeat{2}          - LP blocks
%               out.p_repeat_plot{1}     - TP blocks
%               out.p_repeat_plot{2}     - LP blocks
%               out.feedback_effect{1}   - TP blocks
%               out.feedback_effect{2}   - LP blocks
%
% CODING
%   PREV_F
%       Feedback valence after sign-flipping feedback from untruthful
%       sources:
%           -0.5 = negative implied feedback
%           +0.5 = positive implied feedback
%
%   TRUE
%       Source truthfulness:
%           -0.5 = untruthful (1-/2-star)
%           +0.5 = truthful   (3-/4-star)
%
%   CERTAIN
%       Source certainty:
%           -0.5 = uncertain (2-/3-star)
%           +0.5 = certain   (1-/4-star)
%
%   BETTER
%       Previous choice:
%           -0.5 = worse bandit
%           +0.5 = better bandit
%
%   BASE_RATE (Study 2 only)
%           -0.5 = Lie-Prevalent   (LP)
%           +0.5 = Truth-Prevalent (TP)
%
% NOTES
%   Feedback from 1- and 2-star sources is sign-flipped so that PREV_F
%   represents the outcome implied to be true rather than the literal
%   feedback.


%% Settings

colors = [255 127   0;
          253 191 111;
          166 206 227;
           55 126 184] / 255;

cred = sort(unique(data{1,2}.cred), 'ascend');


%% ========================================================================
%  STUDY 1
%  ========================================================================

if study == 1

    [mdl, out.p_repeat] = fit_study1(data, cred);

    [out.p_repeat_plot, out.feedback_effect] = ...
        compute_feedback_effect(out.p_repeat);


    %% Plot choice repetition

    figure

    x = [1 2 3.5 4.5 6 7 8.5 9.5];

    % Put negative and positive implied feedback next to each other
    plot_data = out.p_repeat_plot(:,[1 5 2 6 3 7 4 8]);
    plot_colors = repelem(colors, 2, 1);

    % Connect positive/negative feedback means within each source
    for source = 1:4

        idx = 2*source + [-1 0];

        plot( ...
            x(idx), ...
            mean(plot_data(:,idx),1,'omitnan'), ...
            '-', ...
            'LineWidth',2, ...
            'Color',[0.3 0.3 0.3]);

        hold on
    end

    plot_swarm_summary( ...
        plot_data, ...
        x, ...
        {'☹','$','☹','$','☹','$','☹','$'}, ...
        plot_colors, ...
        'Previous feedback', ...
        'P(repeat)', ...
        true);


    %% Plot feedback effect

    figure

    plot([0 3],[0 0],'k--')
    hold on

    plot_2by2( ...
        out.feedback_effect, ...
        [2.1 1.1 0.9 1.9], ...
        {'Uncertain','Certain'}, ...
        1, ...
        colors, ...
        'Feedback effect on choice-repetition');


%% ========================================================================
%  STUDY 2
%  ========================================================================

elseif study == 2

    [mdl, p_repeat] = fit_study2(data, cred);

    for condition = 1:2

        out.p_repeat{condition} = ...
            p_repeat(:,:,:,:,condition);

        [out.p_repeat_plot{condition}, ...
         out.feedback_effect{condition}] = ...
            compute_feedback_effect(out.p_repeat{condition});

    end

    condition_names = {'Truth-prevalent','Lie-prevalent'};


    %% Plot choice repetition

    figure

    for condition = 1:2

        subplot(2,1,condition)

        x = [1 2 3.5 4.5 6 7 8.5 9.5];

        plot_data = ...
            out.p_repeat_plot{condition}(:,[1 5 2 6 3 7 4 8]);

        plot_colors = repelem(colors, 2, 1);

        % Connect positive/negative feedback means within each source
        for source = 1:4

            idx = 2*source + [-1 0];

            plot( ...
                x(idx), ...
                mean(plot_data(:,idx),1,'omitnan'), ...
                '-', ...
                'LineWidth',2, ...
                'Color',[0.3 0.3 0.3]);

            hold on
        end

        plot_swarm_summary( ...
            plot_data, ...
            x, ...
            {'☹','$','☹','$','☹','$','☹','$'}, ...
            plot_colors, ...
            'Previous feedback', ...
            'P(repeat)', ...
            true);

        title(condition_names{condition})

    end


    %% Plot feedback effect

    figure

    for condition = 1:2

        subplot(1,2,condition)

        plot([0 3],[0 0],'k--')
        hold on

        plot_2by2( ...
            out.feedback_effect{condition}, ...
            [2.1 1.1 0.9 1.9], ...
            {'Uncertain','Certain'}, ...
            1, ...
            colors, ...
            'Feedback effect on choice-repetition');

        title(condition_names{condition})
        ylim([-0.1 0.4])

    end

    % Remove duplicated y-axis information
    subplot(1,2,2)
    ylabel('')
    yticklabels({})


else
    error('study must be 1 or 2.')
end

end


%% ========================================================================
%  STUDY 1 MIXED-EFFECTS MODEL
%  ========================================================================
function [mdl, p_repeat] = fit_study1(data, cred)
% FIT_STUDY1
%
% Computes participant-level repeat probabilities and fits the Study 1
% mixed-effects binomial regression.
%
% MODEL
%   REPEAT ~ BETTER + PREV_F*CERTAIN*TRUE
%          + (BETTER + PREV_F*CERTAIN*TRUE | SS)
%
% OUTPUTS
%   mdl      - Fitted generalized linear mixed-effects model.
%
%   p_repeat - Participant x source x feedback x accuracy array.


nSub = size(data,1);

p_repeat = nan(nSub, length(cred), 2, 2);

REPEAT = [];
OPPORTUNITIES = [];
PREV_F = [];
BETTER = [];
TRUE = [];
CERTAIN = [];
SS = [];


for ss = 1:nSub
    for source = 1:length(cred)
        for feedback = 0:1
            for better = 0:1

                valid = ...
                    data{ss,2}.cred(:,1:end-1) == cred(source) & ...
                    data{ss,2}.feedback(:,1:end-1) == feedback & ...
                    data{ss,2}.accuracy(:,1:end-1) == better & ...
                    data{ss,2}.pick(:,1:end-1) ~= 0 & ...
                    data{ss,2}.pick(:,2:end) ~= 0;

                repeated = valid & ...
                    data{ss,2}.pick(:,1:end-1) == ...
                    data{ss,2}.pick(:,2:end);

                n = sum(valid,'all');


                % Participant-level probability for plotting
                if n > 0
                    p_repeat(ss,source,feedback+1,better+1) = ...
                        sum(repeated,'all') / n;
                end


                % Counts for binomial GLME
                REPEAT(end+1) = sum(repeated,'all');
                OPPORTUNITIES(end+1) = n;

                TRUE(end+1) = ...
                    ismember(source,[3 4]) - 0.5;

                CERTAIN(end+1) = ...
                    ismember(source,[1 4]) - 0.5;

                % Sign-flip feedback from untruthful sources
                if ismember(source,[1 2])
                    PREV_F(end+1) = 1 - feedback - 0.5;
                else
                    PREV_F(end+1) = feedback - 0.5;
                end

                BETTER(end+1) = better - 0.5;
                SS(end+1) = ss;

            end
        end
    end
end


%% Fit model

tbl = table( ...
    REPEAT', PREV_F', BETTER', CERTAIN', TRUE', SS', ...
    'VariableNames', ...
    {'REPEAT','PREV_F','BETTER','CERTAIN','TRUE','SS'});

keep = OPPORTUNITIES > 0;

formula = [ ...
    'REPEAT ~ 1 + BETTER + PREV_F*(CERTAIN*TRUE) + ' ...
    '(BETTER + PREV_F*(CERTAIN*TRUE) + 1|SS)' ];

mdl = fitglme( ...
    tbl(keep,:), ...
    formula, ...
    'Distribution','Binomial', ...
    'BinomialSize',OPPORTUNITIES(keep), ...
    'FitMethod','Laplace', ...
    'CheckHessian',true);

end


%% ========================================================================
%  STUDY 2 MIXED-EFFECTS MODEL
%  ========================================================================
function [mdl, p_repeat] = fit_study2(data, cred)
% FIT_STUDY2
%
% Computes participant-level repeat probabilities separately for the two
% base-rate conditions and fits the Study 2 pre-registered mixed-effects
% binomial regression.
%
% FIXED EFFECTS
%   REPEAT ~ BETTER + PREV_F*TRUE*(CERTAIN + BASE_RATE)
%
% RANDOM EFFECTS
%   (1 + BETTER + PREV_F + TRUE + CERTAIN + BASE_RATE | SS)
%
% OUTPUTS
%   mdl      - Fitted generalized linear mixed-effects model.
%
%   p_repeat - Participant x source x feedback x accuracy x condition
%              array.
%
%              condition 1 = Truth-Prevalent
%              condition 2 = Lie-Prevalent


nSub = size(data,1);

p_repeat = nan(nSub, length(cred), 2, 2, 2);

REPEAT = [];
OPPORTUNITIES = [];
PREV_F = [];
BETTER = [];
TRUE = [];
CERTAIN = [];
BASE_RATE = [];
SS = [];


for ss = 1:nSub
    for condition = 1:2
        for source = 1:length(cred)
            for feedback = 0:1
                for better = 0:1

                    valid = ...
                        data{ss,2}.cred(:,1:end-1) == cred(source) & ...
                        data{ss,2}.condition(:,1:end-1) == condition & ...
                        data{ss,2}.feedback(:,1:end-1) == feedback & ...
                        data{ss,2}.accuracy(:,1:end-1) == better & ...
                        data{ss,2}.pick(:,1:end-1) ~= 0 & ...
                        data{ss,2}.pick(:,2:end) ~= 0;

                    repeated = valid & ...
                        data{ss,2}.pick(:,1:end-1) == ...
                        data{ss,2}.pick(:,2:end);

                    n = sum(valid,'all');


                    % Participant-level probability for plotting
                    if n > 0
                        p_repeat( ...
                            ss,source,feedback+1,better+1,condition) = ...
                            sum(repeated,'all') / n;
                    end


                    % Counts for binomial GLME
                    REPEAT(end+1) = sum(repeated,'all');
                    OPPORTUNITIES(end+1) = n;

                    TRUE(end+1) = ...
                        ismember(source,[3 4]) - 0.5;

                    CERTAIN(end+1) = ...
                        ismember(source,[1 4]) - 0.5;

                    % condition 1 = TP (+0.5)
                    % condition 2 = LP (-0.5)
                    BASE_RATE(end+1) = ...
                        1.5 - condition;

                    % Sign-flip feedback from untruthful sources
                    if ismember(source,[1 2])
                        PREV_F(end+1) = 1 - feedback - 0.5;
                    else
                        PREV_F(end+1) = feedback - 0.5;
                    end

                    BETTER(end+1) = better - 0.5;
                    SS(end+1) = ss;

                end
            end
        end
    end
end


%% Fit model

tbl = table( ...
    REPEAT', ...
    PREV_F', ...
    BETTER', ...
    CERTAIN', ...
    TRUE', ...
    BASE_RATE', ...
    SS', ...
    'VariableNames', ...
    {'REPEAT','PREV_F','BETTER','CERTAIN','TRUE','BASE_RATE','SS'});

keep = OPPORTUNITIES > 0;

formula = [ ...
    'REPEAT ~ 1 + BETTER + PREV_F*TRUE*(CERTAIN + BASE_RATE) + ' ...
    '(1 + BETTER + PREV_F + TRUE + CERTAIN + BASE_RATE|SS)' ];

mdl = fitglme( ...
    tbl(keep,:), ...
    formula, ...
    'Distribution','Binomial', ...
    'BinomialSize',OPPORTUNITIES(keep), ...
    'FitMethod','Laplace', ...
    'CheckHessian',true);

end


%% ========================================================================
%  PLOTTING QUANTITIES
%  ========================================================================
function [p_repeat_plot, feedback_effect] = compute_feedback_effect(p_repeat)
% COMPUTE_FEEDBACK_EFFECT
%
% Averages repeat probabilities across previous-choice accuracy, sign-flips
% feedback from untruthful sources, and calculates the feedback effect.
%
% INPUT
%   p_repeat - Participant x source x feedback x accuracy array.
%
% OUTPUTS
%   p_repeat_plot
%       Participant x 8 matrix containing negative and positive implied
%       feedback probabilities for each source.
%
%   feedback_effect
%       Participant x 4 matrix containing:
%
%         P(repeat | positive implied feedback)
%       - P(repeat | negative implied feedback)


% Average across whether previous choice was better/worse
p_repeat_plot = [ ...
    mean(p_repeat(:,:,1,:),4), ...
    mean(p_repeat(:,:,2,:),4)];


% Sign-flip feedback for 1- and 2-star sources
p_repeat_plot(:,[1 5 2 6]) = ...
    p_repeat_plot(:,[5 1 6 2]);


% Feedback effect
feedback_effect = ...
    p_repeat_plot(:,5:8) - p_repeat_plot(:,1:4);

end