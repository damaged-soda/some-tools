# 目标安装路径
INSTALL_DIR := /usr/local/bin

# 递归查找所有子目录中的 scripts 下的文件
SCRIPTS := $(shell find . -type f -path "*/scripts/*")

install:
	@echo "Installing scripts to $(INSTALL_DIR)..."
	@for file in $(SCRIPTS); do \
		if [ -f $$file ]; then \
			sudo install -m 755 $$file $(INSTALL_DIR); \
			echo "Installed $$file"; \
		fi \
	done
	@echo "All scripts installed successfully."
