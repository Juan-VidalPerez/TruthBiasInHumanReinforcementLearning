function plot_2by2(data, my_x_ticks, x_tick_labels, sw, colors, y_label)

%
% Plots a 2 x 2 design using participant-level values, group means,
% connecting lines, and SEM error bars.
%
% INPUTS
%   data          - nParticipant x 4 matrix containing the four conditions.
%
%   my_x_ticks    - 1 x 4 vector specifying the x-position of each
%                   condition. Columns 1-2 are connected by one line and
%                   columns 3-4 by another.
%
%   x_tick_labels - Cell array with the two x-axis labels.
%
%   sw            - Whether to display participant-level swarm points:
%                       1 = show swarm
%                       0 = do not show swarm
%
%   colors        - 4 x 3 RGB matrix specifying the color of each
%                   condition.
%
%   y_label       - Label for the y-axis.
%
% OUTPUT
%   None. The function plots into the current axes.
%
% NOTES
%   Error bars represent SEM across participants:
%       SD / sqrt(N)


%% Participant-level observations

if sw == 1
    for p = 1:size(data,2)

        swarmchart( ...
            ones(size(data,1),1) * my_x_ticks(p), ...
            data(:,p), ...
            5, ...
            colors(p,:), ...
            'filled', ...
            'XJitterWidth', 0.1, ...
            'MarkerFaceAlpha', 0.5, ...
            'MarkerEdgeAlpha', 0.5);

        hold on
    end
end


%% Connect condition means

% Conditions 1-2
plot( ...
    my_x_ticks([1 2]), ...
    mean(data(:,[1 2]),1,'omitnan'), ...
    '-', ...
    'LineWidth', 2, ...
    'Color', mean(colors(1:2,:),1));

hold on

% Conditions 3-4
plot( ...
    my_x_ticks([3 4]), ...
    mean(data(:,[3 4]),1,'omitnan'), ...
    '-', ...
    'LineWidth', 2, ...
    'Color', mean(colors(3:4,:),1));

hold on


%% Group means and SEM

for p = 1:4

    errorbar( ...
        my_x_ticks(p), ...
        mean(data(:,p),'omitnan'), ...
        std(data(:,p),'omitnan') / sqrt(size(data,1)), ...
        'Color', [0 0 0], ...
        'LineWidth', 1.25, ...
        'CapSize', 0);

    hold on

    plot( ...
        my_x_ticks(p), ...
        mean(data(:,p),'omitnan'), ...
        'o', ...
        'Color', colors(p,:), ...
        'LineWidth', 1.25, ...
        'MarkerSize', 8, ...
        'MarkerFaceColor', colors(p,:), ...
        'MarkerEdgeColor', 'black');

    hold on
end


%% Axes

xticks([1 2])
xticklabels(x_tick_labels)

ylabel(y_label)

xlim([0.75 2.25])

end