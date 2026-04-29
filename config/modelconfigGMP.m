function [model] = modelconfigGMP
    % Model configuration
    % Periodic extension performs a cyclic extension so that the output has 
    % the same length that the input.
    model.pe = 1;
    model.h=[];
    model.type = 'GMP';
    model.calculation = 'pinv_norm';
    
    % Model configuration according to D. R. Morgan, Z. Ma, J. Kim, M. G. 
    % Zierdt and J. Pastalan, "A Generalized Memory Polynomial Model for 
    % Digital Predistortion of RF Power Amplifiers," in IEEE Transactions on 
    % Signal Processing, vol. 54, no. 10, pp. 3852-3860, Oct. 2006, 
    % doi: 10.1109/TSP.2006.879264.
    
    % Part A: memory polynomial. Order 11 (only odd orders).
    model.Ka = [0:2:12];
    model.La = [10*ones(size(model.Ka))];
    
    % Part B: not diagonal terms. Delayed envelope. Order 11 (only odd orders).
    model.Kb = [2 4 6];
    model.Lb = [1 1 1];
    model.Mb = [1 1 1];
    
    % Part C: not diagonal terms. Advanced envelope. Order 11 (only odd orders).
    model.Kc = [2 4 6];
    model.Lc = [1 1 1];
    model.Mc = [1 1 1];
end