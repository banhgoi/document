FROM centos:latest

# Cập nhật hệ thống và cài đặt các gói phần mềm cần thiết
RUN yum update -y && yum install -y openssh-server sudo

# Tạo thư mục cho SSH daemon
RUN mkdir /var/run/sshd

# Tạo user mới và đặt mật khẩu cho user
RUN useradd -rm -d /home/docker -s /bin/bash -g root -G sudo -u 1000 docker
RUN echo 'docker:docker' | chpasswd

# Cho phép user 'docker' sử dụng sudo mà không cần mật khẩu
RUN echo 'docker ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# Thay đổi cấu hình SSH để cho phép đăng nhập root qua SSH (không khuyến khích trong môi trường thực tế)
RUN sed -i 's/PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
RUN sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config

# Mở cổng 22
EXPOSE 22

# Khởi động SSH daemon
CMD ["/usr/sbin/sshd", "-D"]