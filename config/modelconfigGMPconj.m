%% Model configuration
% Periodic extension performs a cyclic extension so that the output has 
% the same length that the input.
model.pe = 1;
model.h=[];
model.type = 'GMPconj';
model.calculation = 'pinv';

% Model configuration according to D. R. Morgan, Z. Ma, J. Kim, M. G. 
% Zierdt and J. Pastalan, "A Generalized Memory Polynomial Model for 
% Digital Predistortion of RF Power Amplifiers," in IEEE Transactions on 
% Signal Processing, vol. 54, no. 10, pp. 3852-3860, Oct. 2006, 
% doi: 10.1109/TSP.2006.879264.
% A part D will been added similar to part A but depending on the complex
% conjugate of the input signal.

% Part A: memory polynomial. Order 13 and fading memory. Part D similar to part A.
model.Ka = [0:1:12];
model.La = [100 50 40 30 20 10 5*ones(1,length(model.Ka)-6)];

% Part B: not diagonal terms. Delayed envelope. Order 13 and fading memory.
model.Kb = [1:1:12];
model.Lb = [50 40 30 20 10 5*ones(1,length(model.Kb)-5)];
model.Mb = 5*ones(size(model.Kb));

% Part B: not diagonal terms. Advanced envelope. Order 13 and fading memory.
model.Kc = [1:1:12];
model.Lc = [50 40 30 20 10 5*ones(1,length(model.Kc)-5)];
model.Mc = 5*ones(size(model.Kc));


