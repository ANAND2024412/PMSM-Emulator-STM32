clc; clear; close all;
%% ------------------- System definition -------------------------
num = [4.705, 2.219];
den = [1, 7.504, 3.36, 2.702];
G = tf(num, den);
fprintf('Original Continuous Transfer Function:\n');
G

%% ------------------- Settings ----------------------------------
Ts_values = [0.001 0.01 0.1 1 2 3 5 10];   % sampling times
methods = {'zoh','foh','tustin','matched'};
t_final = 10;

%% ------------------- Storage -----------------------------------
Results = {};
Metrics = {};
Output = struct();

%% ------------------- Frequency grid -----------------------------
w = logspace(-2,2,500);

%% ------------------- Main loop ---------------------------------
for iTs = 1:length(Ts_values)
    Ts = Ts_values(iTs);
    t = 0:Ts:t_final;
    [yc, tc] = step(G, t_final);
    y_cont_on_t = interp1(tc, yc, t, 'linear', 'extrap');
    Output(iTs).Ts = Ts;
    Output(iTs).Methods = repmat(struct(),1,length(methods));
    for j = 1:length(methods)
        method = methods{j};
        Gd = c2d(G, Ts, method);
        [y_disc, ~] = step(Gd, t);
        y1 = y_cont_on_t(:);
        y2 = y_disc(:);
        N = min(length(y1), length(y2));
        y1 = y1(1:N);
        y2 = y2(1:N);
        t_common = t(1:N)';
        errVec = y1 - y2;
        MSE  = mean(errVec(:).^2);
        RMSE = sqrt(MSE);
        MAE  = mean(abs(errVec(:)));
        IAE  = trapz(t_common, abs(errVec));
        [magC, phaseC] = bode(G, w);
        [magD, phaseD] = bode(Gd, w);
        magC = squeeze(magC); magD = squeeze(magD);
        phaseC = squeeze(phaseC); phaseD = squeeze(phaseD);
        mag_err   = norm(magC - magD,2);
        phase_err = norm(phaseC - phaseD,2);
        try
            diffSys = G - d2c(Gd,'tustin');
            Hinf_err = norm(diffSys,inf);
        catch
            Hinf_err = NaN;
        end
        pz = pole(Gd);
        max_radius = max(abs(pz));
        [b,a] = tfdata(Gd,'v');
        isJuryStable = juryTest(a);
        numStr = sprintf('%.8f', b(1));
        for k=2:length(b)
            coef = b(k);
            if coef >= 0
                numStr = [numStr, sprintf(' + %.8f z^-%.0f', coef, k-1)];
            else
                numStr = [numStr, sprintf(' - %.8f z^-%.0f', abs(coef), k-1)];
            end
        end
        denStr = '1';
        for k=2:length(a)
            coef = a(k);
            if coef >= 0
                denStr = [denStr, sprintf(' + %.8f z^-%.0f', coef, k-1)];
            else
                denStr = [denStr, sprintf(' - %.8f z^-%.0f', abs(coef), k-1)];
            end
        end
        Hz_str = ['(' numStr ') / (' denStr ')'];
        Results(end+1,:) = {Ts, method, Hz_str};
        Metrics(end+1,:) = {Ts, method, MSE, RMSE, MAE, IAE, ...
                            mag_err, phase_err, Hinf_err, ...
                            max_radius, isJuryStable};
        Output(iTs).Methods(j).Name   = method;
        Output(iTs).Methods(j).Hz_str = Hz_str;
        Output(iTs).Methods(j).y1     = y1;
        Output(iTs).Methods(j).y2     = y2;
        Output(iTs).Methods(j).t      = t_common;
    end
end

%% ------------------- Metrics Table ----------------------------
MetricsTbl = cell2table(Metrics, ...
    'VariableNames', {'Ts','Method','MSE','RMSE','MAE','IAE', ...
                      'MagErr','PhaseErr','HinfErr', ...
                      'MaxPoleRadius','JuryStable'});
disp('==================== Full Metrics Table ====================');
disp(MetricsTbl);

%% =================== Analysis Summary (Fixed Ts, All Plots) =========
for iTs = 1:length(Output)
    Ts = Output(iTs).Ts;
    figure('Name',['Analysis Summary Ts=' num2str(Ts)],'Position',[100 100 1200 800]);
    subplot(2,2,1);
    plot(Output(iTs).Methods(1).t, Output(iTs).Methods(1).y1,'k','LineWidth',1.5); hold on;
    for j=1:length(methods)
        % Use stairs each for discrete? No: Only the *per method* plot is stair—leave combined as lines for easy superposition
        plot(Output(iTs).Methods(j).t, Output(iTs).Methods(j).y2,'--','LineWidth',1.2);
    end
    legend(['Continuous', methods],'Location','Best');
    grid on; title(['Combined Step Response Ts = ' num2str(Ts)]);
    xlabel('Time (s)'); ylabel('Amplitude');
    subplot(2,2,2);
    for j=1:length(methods)
        plot(Output(iTs).Methods(j).t, Output(iTs).Methods(j).y1 - Output(iTs).Methods(j).y2, ...
            'LineWidth',1.2); hold on;
    end
    legend(methods,'Location','Best'); grid on;
    title('Error Signals (Continuous - Discrete)'); xlabel('Time (s)'); ylabel('Error');
    subplot(2,2,3);
    bodeplot(G,'b'); hold on;
    for j=1:length(methods)
        Gd = c2d(G, Ts, methods{j});
        bodeplot(Gd,'--'); 
    end
    grid on; title('Bode Magnitude/Phase');
    legend(['Continuous',methods]);
    subplot(2,2,4);
    for j=1:length(methods)
        Gd = c2d(G, Ts, methods{j});
        pzmap(Gd); hold on;
    end
    grid on; title('Pole-Zero Maps (Unit Circle Included)');
    legend(methods);
end

%% =================== Step Response per Method (Fixed Ts - User Request) =========
for iTs = 1:length(Output)
    Ts = Output(iTs).Ts;
    figure('Name',['Step Responses Vs Methods (Ts = ' num2str(Ts) ' s)'],'Position',[100 100 1000 700]);
    sgtitle(['Continuous vs Discrete Step Responses (Ts = ' num2str(Ts) ' s)']);
    for j = 1:length(methods)
        methodData = Output(iTs).Methods(j);
        subplot(2, 2, j);
        % Continuous response (blue solid line)
        plot(methodData.t, methodData.y1, 'b', 'LineWidth', 1.5); hold on;
        % Discrete response (red dashed stair step)
        stairs(methodData.t, methodData.y2, 'r--', 'LineWidth', 1.2);
        grid on;
        title(upper(methodData.Name));
        xlabel('Time (s)');
        ylabel('Amplitude');
        legend('Continuous', 'Discrete', 'Location', 'Best');
        hold off;
    end
end

%% =================== Step Responses (Ts variation per Method) ========================
methodsUnique = unique(MetricsTbl.Method);
for j=1:length(methodsUnique)
    method = methodsUnique{j};
    figure('Name',['Step Responses across Ts: ' method],'Position',[100 100 1200 800]);
    for iTs = 1:length(Output)
        Ts = Output(iTs).Ts;
        subplot(2,ceil(length(Output)/2),iTs);  
        plot(Output(iTs).Methods(j).t, Output(iTs).Methods(j).y1,'b','LineWidth',1.5); hold on;
        stairs(Output(iTs).Methods(j).t, Output(iTs).Methods(j).y2,'r--','LineWidth',1.2); % <<-- stair for method trends too
        grid on;
        title(['Ts = ' num2str(Ts) ' s']);
        xlabel('Time (s)'); ylabel('Amplitude');
        legend('Continuous','Discrete','Location','Best');
    end
    sgtitle(['Step Responses for ' upper(method) ' across Sampling Times']);
end

%% ================= Metrics vs Ts plots ========================
for j=1:length(methodsUnique)
    method = methodsUnique{j};
    idx = strcmp(MetricsTbl.Method,method);
    figure('Name',['Metrics vs Ts: ' method],'Position',[100 100 1200 600]);
    subplot(2,2,1);
    semilogx(MetricsTbl.Ts(idx), MetricsTbl.RMSE(idx),'-o'); grid on;
    title(['RMSE vs Ts (' method ')']); xlabel('Ts (s)'); ylabel('RMSE');
    subplot(2,2,2);
    semilogx(MetricsTbl.Ts(idx), MetricsTbl.MagErr(idx),'-o'); grid on;
    title(['Magnitude Error (L2 Norm) vs Ts (' method ')']); xlabel('Ts (s)'); ylabel('MagErr');
    subplot(2,2,3);
    semilogx(MetricsTbl.Ts(idx), MetricsTbl.PhaseErr(idx),'-o'); grid on;
    title(['Phase Error (L2 Norm) vs Ts (' method ')']); xlabel('Ts (s)'); ylabel('PhaseErr');
    subplot(2,2,4);
    semilogx(MetricsTbl.Ts(idx), MetricsTbl.MaxPoleRadius(idx),'-o'); grid on;
    yline(1.0, 'r--', 'Unstable Boundary', 'LineWidth', 1.5, 'LabelHorizontalAlignment', 'left');
    title(['Max Pole Radius vs Ts (' method ')']); xlabel('Ts (s)'); ylabel('Max |pole|');
end

%% ================= Jury Test Function =========================
function isStable = juryTest(a)
    if isempty(a) || length(a) < 2
        isStable = false; return;
    end
    n = length(a)-1;
    isStable = true;
    a = a./a(1);
    if abs(a(end)) >= a(1), isStable = false; return; end
    if polyval(a,1) <= 0, isStable = false; return; end
    p_minus_1 = polyval(a,-1);
    if mod(n,2)==0
        if p_minus_1 <= 0, isStable = false; return; end
    else
        if p_minus_1 >= 0, isStable = false; return; end
    end
    J = a;
    for k = n:-1:2
        if abs(J(end)) >= abs(J(1)), isStable = false; return; end
        row1 = J(1:k); row2 = fliplr(row1);
        lambda = row1(end)/row1(1);
        nextRow = row1(1:end-1) - lambda * row2(1:end-1);
        J = nextRow;
        if length(J) < 2, break; end
    end
end
