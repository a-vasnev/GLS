%% Bates and Granger (1969) Table 1 data + Barnard (1963)

clear all;
close all;

e0 = 2.75; % the error of combined forecast in Dec 1952

% monthly 1953 data
data = [
    196, 195, 199;
    196, 190, 206;
    236, 218, 212;
    235, 217, 213;
    229, 226, 238;
    243, 260, 265;
    264, 288, 254;
    272, 288, 270;
    237, 249, 248;
    211, 220, 221;
    180, 192, 192;
    201, 214, 208
];

y = data(:,1); % actual
F = data(:,2:3); % Brown and Box-Jenkins forecasts

E = y - F;
MSFE = diag(E'*E)/size(E,1);

w_set = [0:0.01:1]';
MSFE_set = w_set * 0; % preallocation

for l = 1:length(w_set)
    w = w_set(l);
    F_c = w * F(:,1) + (1-w) * F(:,2);
    E_c = y - F_c;
    MSFE_set(l) = (E_c'*E_c)/length(E_c);
end

% equal weight forecast
w_fixed = 0.5;
F_c = w_fixed * F(:,1) + (1-w_fixed) * F(:,2);
E_c = y - F_c;
MSFE_c = (E_c'*E_c)/length(E_c);

rho_set = [0:0.01:1.0]';
MSFE_rho_set = rho_set * 0; % preallocation
for l = 1:length(rho_set)
    rho = rho_set(l);
    F_c_rho = F_c + rho * [e0; E_c(1:end-1)];
    E_c_rho = y - F_c_rho;
    MSFE_rho_set(l) = (E_c_rho'*E_c_rho)/length(E_c_rho);
end

% fixed correction of 0.5
rho_fixed = 0.5;
F_c_rho = F_c + rho_fixed * [e0; E_c(1:end-1)];
E_c_rho = y - F_c_rho;
MSFE_c_rho = (E_c_rho'*E_c_rho)/length(E_c_rho);


%% plot figure
% 2D
plot(w_set, MSFE_set, 'LineWidth', 2);
xlabel('Weight on Brown forecast');
ylabel('MSFE');
title('Mean Squared Forecast Error for Combined Forecast');
grid on;

% 3D
scrsz = get(0,'ScreenSize'); 
gcf=figure('PaperPositionMode','auto','Position',[scrsz(3)/20 scrsz(4)/2 scrsz(3)/(3) scrsz(4)/(3)],'PaperOrientation','landscape'); hold on; % position [left bottom width height]
plot3(w_set, rho_set*0, MSFE_set, 'LineWidth', 2); hold on;
plot3(w_set*0 + 0.5, rho_set, MSFE_rho_set, 'LineWidth', 2)
grid on;
xlabel('Weight on ES forecast');
ylabel('Correction factor')
zlabel('MSFE')
% add individual points
plot3(0.5, 0, MSFE_c, 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r');
plot3(0.5, 0.5, MSFE_c_rho, 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r');
plot3(0, 0, MSFE(2), 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r');
plot3(1, 0, MSFE(1), 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r');

grid off
% add planes
plot3([1 0 0 1 1],[0 0 0 0 0],[60 60 200 200 60],'k')
plot3(0.5*[1 1 1 1 1],[0 0 1 1 0],[60 180 180 60 60],'k')

% add text labels
text(0.45, 0,   MSFE_c     + 10, 'EW',  'FontSize', 10, 'FontWeight', 'bold');
text(0.5, 0.5, MSFE_c_rho + 10, 'CEW', 'FontSize', 10, 'FontWeight', 'bold');
text(0.95, 0, MSFE(1), 'ES', 'FontSize', 10, 'FontWeight', 'bold');
text(0.1, 0, MSFE(2)+5, 'BJ', 'FontSize', 10, 'FontWeight', 'bold');

file_out = '/Users/av/Sydney Uni Dropbox/Andrey Vasnev/Research/2025/GLS project/Draft/fig-BG-v01.pdf';
%exportgraphics(gcf,file_out,'ContentType','vector');