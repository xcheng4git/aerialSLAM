close all;
clear all;
clc;

load('../../datasets/cmu_16662_p3/NSHLevel2_data.mat');
load('../../datasets/cmu_16662_p2/sensor_data/hand_carry.mat');

nImages = size(image_timestamps,2);
nIMU = size(imu_timestamps,2);

[x, y, z] = dcm2angle(rotation_imu_to_leftcam, 'XYZ');
imu_leftcam_R = angle2dcm(x, pi - y, z, 'XYZ');

pT = eye(4,4);
pT(1:3, 1:3) = imu_leftcam_R;
% pT(1:3, 4) = translation_imu_to_leftcam;

counter_IMU = 1;
counter_time = 1;
time = imu_timestamps(1,counter_time);
while time < image_timestamps(1,29)
    counter_time = counter_time + 1;
    time = imu_timestamps(1,counter_time);
end
bias = [1.0*mean(body_accel(1,1:counter_time));1.0*mean(body_accel(2,1:counter_time));1.0012*mean(body_accel(3,1:counter_time))];
imustd = [std(body_accel(1,1:counter_time));std(body_accel(2,1:counter_time));std(body_accel(3,1:counter_time))];
fprintf('Bias Accel\n');
fprintf('%.7f %.7f %.7f\n',bias);


bias_velw = [mean(body_angvel(1,1:counter_time));mean(body_angvel(2,1:counter_time));1*mean(body_angvel(3,1:counter_time))];
imustd_velw = [std(body_angvel(1,1:counter_time));std(body_angvel(2,1:counter_time));std(body_angvel(3,1:counter_time))];
fprintf('Bias Gyro\n');
fprintf('%.7f %.7f %.7f\n',bias_velw);

% GTSAM setup for testing
addpath('../../gtsam-toolbox-3.2.0-win64/gtsam_toolbox');
import gtsam.*

graph = NonlinearFactorGraph;
initial = Values;
dV = [0;0;0];
for label = 2:nImages
    dP = [0;0;0];
    dR = eye(3,3);
    dt = 0;
    while imu_timestamps(1,counter_IMU) < image_timestamps(1,label)
        if dt == 0
            dt = imu_timestamps(1,counter_IMU) - image_timestamps(1,label - 1);
        else
            dt = imu_timestamps(1,counter_IMU) - imu_timestamps(1,counter_IMU - 1);
        end

        dV = dV + (body_accel(:,counter_IMU)-bias)*dt;
        dP = dP + dV*dt;

        w = zeros(3,3);
        w(1,2) = -1*(body_angvel(3,counter_IMU)-bias_velw(3))*dt;
        w(1,3) = (body_angvel(2,counter_IMU)-bias_velw(2))*dt;
        w(2,1) = (body_angvel(3,counter_IMU)-bias_velw(3))*dt;
        w(2,3) = -1*(body_angvel(1,counter_IMU)-bias_velw(1))*dt;
        w(3,1) = -1*(body_angvel(2,counter_IMU)-bias_velw(2))*dt;
        w(3,2) = (body_angvel(1,counter_IMU)-bias_velw(1))*dt;
        dR = dR*expm(w);

        counter_IMU = counter_IMU + 1;
    end
    dTr = [dR,dP;0,0,0,1];
    pT = pT*dTr;
    
    % for testing
    pose = eye(4);
    pose(1:3, 4) = pT(1:3, 4);
    pose(1:3, 1:3) = pT(1:3, 1:3) * inv(imu_leftcam_R);
    if mod(label, 20) == 0
        initial.insert(symbol('x', label-1), Pose3(pose));
    end

end

figure;
hold on;
axis equal;
plot3DTrajectory(initial, 'r', 1, 1);
xlabel('x');
ylabel('y');
zlabel('z');