function timings_2()
    
    clearvars
    nIters = 1000; 
    name = 'post2 (plain matlab)';

    net = sig.Net();
    a = 5; b = 2; c = 8; % Some constants to use in our equation
    x = net.origin('x');
    y = a * (x ^ 2) + b * x + c;
    t0 = tic;
    for i = 1:nIters
        x.post2(3)
    end
    te_post = toc(t0); % time elapsed (post2, matlab only)
   
    y.node


    show_result(nIters, name, te_post);

end


function show_result(nIters, name, te_post)
    usecPerOp = (te_post * 10^6) / nIters;
    fprintf('%-30s  %12.9f  microsecs per iter \n', [name ':'], usecPerOp);
end