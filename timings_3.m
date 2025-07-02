function timings_3()
% Measure execution time of x.post2(3) for polynomials of increasing degree.


    clearvars
    nIters = 10000;
    maxDegree = 10;

    % Measure post2 (plain matlab)
    timings_post2 = measure_timings(nIters, maxDegree);


    % Show all results
    fprintf('%-10s  %-25s \n', 'Degree', 'post2 (plain matlab)');
    for degree = 1:maxDegree
        fprintf('%-10d  %-25.3f \n',degree, timings_post2(degree));
    end

    % Plot
    figure;
    degrees = 1:maxDegree;
    plot(degrees, timings_post2, '-o', 'LineWidth', 2);
    xlabel('Polynomial Degree');
    ylabel('Avg Time per Iteration (\mus)');
    title('Timing of x.post2(3) vs Polynomial Degree');
    grid on;

end

function timings = measure_timings(nIters, maxDegree)

    timings = zeros(maxDegree, 1);
    for degree = 1:maxDegree
        clear net
        net = sig.Net(100);
        x = net.origin('x');
        y = 0;
        for d = 1:degree
            coeff = d + 1;
            y = y + coeff * (x ^ d);
        end
        t0 = tic;
        for i = 1:nIters
%             fprintf('Degree: %d \n', degree)
            x.post2(3);
        end
        elapsed = toc(t0);
        timings(degree) = (elapsed * 1e6) / nIters;
    end
    y.node
end
