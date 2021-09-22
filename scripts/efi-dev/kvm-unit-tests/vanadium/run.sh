#!/bin/bash

# Create file for EFI vars.
rm -f efivars.txt
touch efivars.txt

# Remove and recreate delta disks.
rm -f delta.* -f
dd if=/dev/zero of=delta.bmp bs=1 count=0 seek=13M
dd if=/dev/zero of=delta.raw bs=1 count=0 seek=10G

sev=false
sev_es=false
sev_snp=false
inject_kernel=false
inject_ovmf=false
secure_boot=false
num_vcpus=1
vm_ram=1024
container_ram=$((vm_ram + 8192)) # container to run the vm should have more ram than vm, set to +8Gb for now
# Use these vm_specs if needed.
vm_specs_file=""
disk_image=app.img

declare -a args

# Very basic logging function.
function log() {
  level="${1}"
  message="${2}"

  case "${level}" in
    "info"|"INFO")
      level="INF"
      ;;
    "error"|"ERROR")
      level="ERR"
      ;;
    "warning"|"WARNING")
      level="WRN"
      ;;
    *)
      echo "[$(date)] ERR - Invalid logging level ${level}"
      exit 1
  esac

  echo "[$(date)] ${level} - ${message}"
}

# Make sure the SEV module is loaded.
function reload_sev_module() {
  rmmod kvm_amd # not needed if running this the 1st boot (no problem if it gives an error)
  rmmod ccp
  # insmod /lib/modules/$(uname -r)/kernel/drivers/crypto/ccp/ccp.ko psp_nv_file=/export/hda3/psp_nv_file
  # insmod /lib/modules/$(uname -r)/kernel/arch/x86/kvm/kvm-amd.ko sev=1 sev_snp=1
  # udevadm test /devices/virtual/misc/sev
  modprobe kvm_amd sev=1
  chmod a+rw /dev/kvm
  chmod a+rw /mnt/devtmpfs/sev
  # rm -f /chroots/borg/dev/sev && ln /dev/sev /chroots/borg/dev/sev
}


# Create the VmSpec.
#
function create_vm_spec() {

  cat > vmspec.pb.txt <<EOL
pci_card {
  slot: 0
  device_spec {
    logical_name: "nvme0"
    [cloud_vmm_proto.NVMeSpec.extension] {
      backend: "disk-0"
      max_queue_entries: 4095
      num_io_queues: 1
      doorbell_stride_shift: 0
      version: 4
      max_data_transfer_size_shift: 5
    }
  }
}
EOL

if [[ "${secure_boot}" == true ]]; then
    cat >> vmspec.pb.txt <<EOL
isa_devices {
  [cloud_vmm_proto.Tpm.extension] {
    backend: "tpm_backend"
    persistent_storage_backend: "tpm_nvdata_storage_backend"
  }
}
EOL
  fi
    cat >> vmspec.pb.txt <<EOL
isa_devices {
  [cloud_vmm_proto.PvUefi.extension] {
    storage_backend: "pvuefi_storage_backend"
    enable_secure_boot: ${secure_boot}
  }
}
isa_devices {
  [cloud_vmm_proto.Port.extension] {
    id: SERIAL_A
    backend: "SERIAL_A-composite"
  }
}
isa_devices {
  [cloud_vmm_proto.Port.extension] {
    id: SERIAL_B
    backend: "console-composite"
  }
}
isa_devices {
  [cloud_vmm_proto.Port.extension] {
    id: SERIAL_C
    backend: "SERIAL_C-composite"
  }
}
isa_devices {
  [cloud_vmm_proto.Port.extension] {
    id: SERIAL_D
    backend: "SERIAL_D-composite"
  }
}
isa_devices {
  [cloud_vmm_proto.BiosDebug.extension] {
    id: DEBUG
    backend: "bios_log"
  }
}
isa_devices {
  [cloud_vmm_proto.PvPanic.extension] {
  }
}
isa_devices {
  [cloud_vmm_proto.I8042.extension] {
    keyboard {
      head_backend: "dummy_keyboard"
    }
  }
}
backends {
  logical_name: "pvuefi_storage_backend"
  [cloud_vmm_proto.PvUefiStorageBackendFileSpec.extension] {
    filename: "$(pwd)/efivars.txt"
  }
}
EOL

if [[ "${secure_boot}" == true ]]; then
    cat >> vmspec.pb.txt <<EOL
backends {
  logical_name: "tpm_nvdata_storage_backend"
  [cloud_vmm_proto.PersistentStorageBackendFileSpec.extension] {
    filename: "tpm_nvdata_storage_backend-store.txt"
  }
}
backends {
  logical_name: "tpm_test_certissuer"
  [cloud_vmm_proto.CertIssuerBackendSpec.extension] {
    persistent_storage_backend: "tpm_nvdata_storage_backend"
  }
}
backends {
  logical_name: "tpm_integrity_backend"
  [cloud_vmm_proto.IntegrityBackendSpec.extension] {
    persistent_storage_backend: "tpm_nvdata_storage_backend"
    skip_first_boot_measurement: false
  }

backends {
  logical_name: "tpm_backend"
  [cloud_vmm_proto.SoftwareTpmBackendSpec.extension] {
    persistent_storage_backend: "tpm_nvdata_storage_backend"
    integrity_backend: "tpm_integrity_backend"
    cert_issuer_backend: "tpm_test_certissuer"
  }
}
EOL
  fi

  cat >> vmspec.pb.txt <<EOL
backends {
  logical_name: "SERIAL_A-log"
  [cloud_vmm_proto.TubeBackendLogSpec.extension] {
    prefix: "kernel_ttyS0"
  }
}
backends {
  logical_name: "SERIAL_A"
  [cloud_vmm_proto.TubeBackendStreamServerSpec.extension] {
  }
}
backends {
  logical_name: "SERIAL_A-streamz"
  [cloud_vmm_proto.TubeBackendStreamzSpec.extension] {
  }
}
backends {
  logical_name: "SERIAL_A-html"
  [cloud_vmm_proto.TubeBackendHtmlSpec.extension] {
  }
}
backends {
  logical_name: "SERIAL_A-composite"
  [cloud_vmm_proto.TubeBackendCompositeSpec.extension] {
    child {
      backend: "SERIAL_A-log"
      may_read: false
      may_write: true
    }
    child {
      backend: "SERIAL_A"
      may_read: true
      may_write: true
    }
    child {
      backend: "SERIAL_A-streamz"
      may_read: false
      may_write: true
    }
    child {
      backend: "SERIAL_A-html"
      may_read: true
      may_write: true
    }
  }
}
backends {
  logical_name: "console-log"
  [cloud_vmm_proto.TubeBackendLogSpec.extension] {
    prefix: "CONSOLE"
  }
}
backends {
  logical_name: "console"
  [cloud_vmm_proto.TubeBackendStreamServerSpec.extension] {
  }
}
backends {
  logical_name: "console-streamz"
  [cloud_vmm_proto.TubeBackendStreamzSpec.extension] {
  }
}
backends {
  logical_name: "console-html"
  [cloud_vmm_proto.TubeBackendHtmlSpec.extension] {
  }
}
backends {
  logical_name: "console-composite"
  [cloud_vmm_proto.TubeBackendCompositeSpec.extension] {
    child {
      backend: "console-log"
      may_read: false
      may_write: true
    }
    child {
      backend: "console"
      may_read: true
      may_write: true
    }
    child {
      backend: "console-streamz"
      may_read: false
      may_write: true
    }
    child {
      backend: "console-html"
      may_read: true
      may_write: true
    }
  }
}
backends {
  logical_name: "SERIAL_C-log"
  [cloud_vmm_proto.TubeBackendLogSpec.extension] {
    prefix: "SERIAL_C"
  }
}
backends {
  logical_name: "SERIAL_C"
  [cloud_vmm_proto.TubeBackendStreamServerSpec.extension] {
  }
}
backends {
  logical_name: "SERIAL_C-streamz"
  [cloud_vmm_proto.TubeBackendStreamzSpec.extension] {
  }
}
backends {
  logical_name: "SERIAL_C-html"
  [cloud_vmm_proto.TubeBackendHtmlSpec.extension] {
  }
}
backends {
  logical_name: "SERIAL_C-composite"
  [cloud_vmm_proto.TubeBackendCompositeSpec.extension] {
    child {
      backend: "SERIAL_C-log"
      may_read: false
      may_write: true
    }
    child {
      backend: "SERIAL_C"
      may_read: true
      may_write: true
    }
    child {
      backend: "SERIAL_C-streamz"
      may_read: false
      may_write: true
    }
    child {
      backend: "SERIAL_C-html"
      may_read: true
      may_write: true
    }
  }
}
backends {
  logical_name: "SERIAL_D-log"
  [cloud_vmm_proto.TubeBackendLogSpec.extension] {
    prefix: "SERIAL_D"
  }
}
backends {
  logical_name: "SERIAL_D"
  [cloud_vmm_proto.TubeBackendStreamServerSpec.extension] {
  }
}
backends {
  logical_name: "SERIAL_D-streamz"
  [cloud_vmm_proto.TubeBackendStreamzSpec.extension] {
  }
}
backends {
  logical_name: "SERIAL_D-html"
  [cloud_vmm_proto.TubeBackendHtmlSpec.extension] {
  }
}
backends {
  logical_name: "SERIAL_D-composite"
  [cloud_vmm_proto.TubeBackendCompositeSpec.extension] {
    child {
      backend: "SERIAL_D-log"
      may_read: false
      may_write: true
    }
    child {
      backend: "SERIAL_D"
      may_read: true
      may_write: true
    }
    child {
      backend: "SERIAL_D-streamz"
      may_read: false
      may_write: true
    }
    child {
      backend: "SERIAL_D-html"
      may_read: true
      may_write: true
    }
  }
}
backends {
  logical_name: "bios_log"
  [cloud_vmm_proto.TubeBackendLogSpec.extension] {
    prefix: "BIOS"
  }
}
backends {
  logical_name: "history"
  [cloud_vmm_proto.HistoryBackendSpec.extension] {
  }
}
backends {
  logical_name: "logging_stats"
  [cloud_vmm_proto.LoggingStatsBackendSpec.extension] {
  }
}
backends {
  logical_name: "block_stats"
  [cloud_vmm_proto.BlockStatsBackendSpec.extension] {
  }
}
backends {
  logical_name: "kvm_stats"
  [cloud_vmm_proto.KvmStatsBackendSpec.extension] {
  }
}
backends {
  logical_name: "vm_stats"
  [cloud_vmm_proto.VmStatsBackendSpec.extension] {
  }
}
backends {
  logical_name: "vm_telemetry"
  [cloud_vmm_proto.VmTelemetryBackendSpec.extension] {
  }
}
backends {
  logical_name: "dummy_keyboard"
  [cloud_vmm_proto.HeadBackendScreenshotSpec.extension] {
  }
}
backends {
  logical_name: "disk-0"
  [cloud_vmm_proto.DeltaDiskBackendSpec.extension] {
    base_disk {
      [cloud_vmm_proto.RawDiskBackendSpec.extension] {
        filename: "$(pwd)/${disk_image}"
        read_only: true
      }
    }
    delta_disk {
      [cloud_vmm_proto.RawDiskBackendSpec.extension] {
        filename: "$(pwd)/delta.raw"
        encrypt: false
      }
    }
    bitmap_filename: "$(pwd)/delta.bmp"
  }
}
board {
  memory {
    ram_mb: ${vm_ram}
EOL

  # Do we want memory encryption enabled?
  if [[ "${sev_snp}" == true ]]; then
    cat >> vmspec.pb.txt <<EOL
    memory_encryption_spec {
      [cloud_vmm_proto.SnpSpec.extension] {
        policy {
          min_abi_major_version: 0
          min_abi_minor_version: 0
          smt: true
          migration_agent: true
          debug: true
        }
      }
    }
EOL
  elif [[ "${sev}" == true ]]; then
    cat >> vmspec.pb.txt <<EOL
    memory_encryption_spec {
      [cloud_vmm_proto.SevSpec.extension] {
        sev_es_required: ${sev_es}
      }
    }
EOL
  fi

  cat >> vmspec.pb.txt <<EOL
  }
EOL
  for (( i=0; i<"${num_vcpus}"; ++i )); do
    cat >> vmspec.pb.txt <<EOL
  cpu {
    enable_xsave: true
    scheduler {
      [cloud_vmm_proto.GuestOnlyVCpuSchedulerSpec.extension] {
      }
    }
  }
EOL
  done
  cat >> vmspec.pb.txt <<EOL
  chipset {
    [cloud_vmm_proto.Piix4Spec.extension] {
    }
  }
  bios_version: UEFI_HEAD
  cpu_identity {
    guest_cpu {
      cpuid {
        entries {
          function: 0
          index: 0
          eax: 13
          ebx: 1752462657
          ecx: 1145913699
          edx: 1769238117
        }
        entries {
          function: 1
          index: 0
          eax: 8589072
          ebx: 526336
          ecx: 4141363715
          edx: 395049983
        }
        entries {
          function: 2
          index: 0
          eax: 0
          ebx: 0
          ecx: 0
          edx: 0
        }
        entries {
          function: 3
          index: 0
          eax: 0
          ebx: 0
          ecx: 0
          edx: 0
        }
        entries {
          function: 4
          index: 0
          eax: 0
          ebx: 0
          ecx: 0
          edx: 0
        }
        entries {
          function: 5
          index: 0
          eax: 0
          ebx: 0
          ecx: 0
          edx: 0
        }
        entries {
          function: 6
          index: 0
          eax: 4
          ebx: 0
          ecx: 0
          edx: 0
        }
        entries {
          function: 7
          index: 0
          eax: 0
          ebx: 563872171
          ecx: 4194308
          edx: 0
        }
        entries {
          function: 8
          index: 0
          eax: 0
          ebx: 0
          ecx: 0
          edx: 0
        }
        entries {
          function: 9
          index: 0
          eax: 0
          ebx: 0
          ecx: 0
          edx: 0
        }
        entries {
          function: 10
          index: 0
          eax: 0
          ebx: 0
          ecx: 0
          edx: 0
        }
        entries {
          function: 11
          index: 0
          eax: 1
          ebx: 2
          ecx: 256
          edx: 0
        }
        entries {
          function: 11
          index: 1
          eax: 3
          ebx: 8
          ecx: 513
          edx: 0
        }
        entries {
          function: 11
          index: 2
          eax: 0
          ebx: 0
          ecx: 2
          edx: 0
        }
        entries {
          function: 12
          index: 0
          eax: 0
          ebx: 0
          ecx: 0
          edx: 0
        }
        entries {
          function: 13
          index: 0
          eax: 7
          ebx: 832
          ecx: 832
          edx: 0
        }
        entries {
          function: 13
          index: 1
          eax: 7
          ebx: 832
          ecx: 0
          edx: 0
        }
        entries {
          function: 13
          index: 2
          eax: 256
          ebx: 576
          ecx: 0
          edx: 0
        }
        entries {
          function: 2147483648
          index: 0
          eax: 2147483679
          ebx: 1752462657
          ecx: 1145913699
          edx: 1769238117
        }
        entries {
          function: 2147483649
          index: 0
          eax: 8589056
          ebx: 1073741824
          ecx: 4195315
          edx: 802421759
        }
        entries {
          function: 2147483650
          index: 0
          eax: 541347137
          ebx: 1129926725
          ecx: 826423072
          edx: 50
        }
        entries {
          function: 2147483651
          index: 0
          eax: 0
          ebx: 0
          ecx: 0
          edx: 0
        }
        entries {
          function: 2147483652
          index: 0
          eax: 0
          ebx: 0
          ecx: 0
          edx: 0
        }
        entries {
          function: 2147483653
          index: 0
          eax: 4282449728
          ebx: 4282449728
          ecx: 537395520
          edx: 537395520
        }
        entries {
          function: 2147483654
          index: 0
          eax: 1207985152
          ebx: 1744856064
          ecx: 33579328
          edx: 134254912
        }
        entries {
          function: 2147483655
          index: 0
          eax: 0
          ebx: 0
          ecx: 0
          edx: 256
        }
        entries {
          function: 2147483656
          index: 0
          eax: 12336
          ebx: 17616901
          ecx: 12295
          edx: 0
        }
        entries {
          function: 2147483657
          index: 0
          eax: 0
          ebx: 0
          ecx: 0
          edx: 0
        }
        entries {
          function: 2147483658
          index: 0
          eax: 1
          ebx: 8
          ecx: 0
          edx: 9
        }
        entries {
          function: 2147483659
          index: 0
          eax: 0
          ebx: 0
          ecx: 0
          edx: 0
        }
        entries {
          function: 2147483660
          index: 0
          eax: 0
          ebx: 0
          ecx: 0
          edx: 0
        }
        entries {
          function: 2147483661
          index: 0
          eax: 0
          ebx: 0
          ecx: 0
          edx: 0
        }
        entries {
          function: 2147483662
          index: 0
          eax: 0
          ebx: 0
          ecx: 0
          edx: 0
        }
        entries {
          function: 2147483663
          index: 0
          eax: 0
          ebx: 0
          ecx: 0
          edx: 0
        }
        entries {
          function: 2147483664
          index: 0
          eax: 0
          ebx: 0
          ecx: 0
          edx: 0
        }
        entries {
          function: 2147483665
          index: 0
          eax: 0
          ebx: 0
          ecx: 0
          edx: 0
        }
        entries {
          function: 2147483666
          index: 0
          eax: 0
          ebx: 0
          ecx: 0
          edx: 0
        }
        entries {
          function: 2147483667
          index: 0
          eax: 0
          ebx: 0
          ecx: 0
          edx: 0
        }
        entries {
          function: 2147483668
          index: 0
          eax: 0
          ebx: 0
          ecx: 0
          edx: 0
        }
        entries {
          function: 2147483669
          index: 0
          eax: 0
          ebx: 0
          ecx: 0
          edx: 0
        }
        entries {
          function: 2147483670
          index: 0
          eax: 0
          ebx: 0
          ecx: 0
          edx: 0
        }
        entries {
          function: 2147483671
          index: 0
          eax: 0
          ebx: 0
          ecx: 0
          edx: 0
        }
        entries {
          function: 2147483672
          index: 0
          eax: 0
          ebx: 0
          ecx: 0
          edx: 0
        }
        entries {
          function: 2147483673
          index: 0
          eax: 4030787648
          ebx: 0
          ecx: 0
          edx: 0
        }
        entries {
          function: 2147483674
          index: 0
          eax: 6
          ebx: 0
          ecx: 0
          edx: 0
        }
        entries {
          function: 2147483675
          index: 0
          eax: 0
          ebx: 0
          ecx: 0
          edx: 0
        }
        entries {
          function: 2147483676
          index: 0
          eax: 0
          ebx: 0
          ecx: 0
          edx: 0
        }
        entries {
          function: 2147483677
          index: 0
          eax: 16673
          ebx: 29360191
          ecx: 63
          edx: 0
        }
        entries {
          function: 2147483677
          index: 1
          eax: 16674
          ebx: 29360191
          ecx: 63
          edx: 0
        }
        entries {
          function: 2147483677
          index: 2
          eax: 16707
          ebx: 29360191
          ecx: 1023
          edx: 2
        }
        entries {
          function: 2147483677
          index: 3
          eax: 115043
          ebx: 62914623
          ecx: 16383
          edx: 1
        }
        entries {
          function: 2147483677
          index: 4
          eax: 0
          ebx: 0
          ecx: 0
          edx: 0
        }
        entries {
          function: 2147483678
          index: 0
          eax: 0
          ebx: 256
          ecx: 0
          edx: 0
        }
        entries {
          function: 2147483679
          index: 0
          eax: 2
          ebx: 47
          ecx: 0
          edx: 0
        }
        entries {
          function: 1073741824
          index: 0
          eax: 1073741825
          ebx: 1263359563
          ecx: 1447775574
          edx: 77
        }
        entries {
          function: 1073741825
          index: 0
          eax: 16777355
          ebx: 0
          ecx: 0
          edx: 0
        }
      }
      tsc_khz: 2250000
      platform_msr {
        index: PLATFORM_MSR_PLATFORM_INFO
        data: 24189255816704
      }
    }
  }
  [cloud_vmm_proto.GcbSpec.extension] {
  }
}
backends {
  logical_name: 'Default'
    [cloud_vmm_proto.QemuBackendSpec.extension] {
EOL

  if [[ "${inject_kernel}" == true ]]; then
    cat >> vmspec.pb.txt <<EOL
      type: STRATEGY_TYPE_FILE
      linux_boot_params {
        injected_kernel: "$(pwd)/bzImage"
        linux_cmd_line: 'earlyprintk=ttyS0 console=ttyS0 efi=noruntime root=/dev/nvme0n1p1'
      }
EOL
  fi

  cat >> vmspec.pb.txt <<EOL
      acpi_table_generation_enabled: true
      acpi_table_bios_usage_type: 1
      acpi_table_uefi_usage_type: 0
      is_csm_boot: false
    }
}
i82441fx_enabled: true
instance_uid: "default_test_instance_uid"
EOL
} # create_vm_spec

#################### MAIN #######################

# Parse parameters.
while (( "$#" ));do
  case "${1}" in
    "--sev-es")
      sev_es=true
      # Fall through.
      ;&
    "--sev")
      sev=true
      ls /mnt/devtmpfs/sev || reload_sev_module
      shift
      ;;
    "--sev-snp")
      sev_snp=true
      ls /mnt/devtmpfs/sev || reload_sev_module
      shift
      ;;
    "-k"|"--inject-kernel")
      inject_kernel=true
      shift
      ;;
    "-o"|"--inject-ovmf")
      inject_ovmf=true
      shift
      ;;
    "--secure-boot")
      secure_boot=true
      shift
      ;;
    "--vm_ram")
      if [[ -n "${2}" ]] && [[ "${2}" -ge 1024 ]]; then
        vm_ram="${2}"
        container_ram=$((vm_ram + 8192))
      else
        log ERROR "Invalid RAM amount ${2}"
      fi
      shift 2
      ;;
    "-v"|"--vcpu_count")
      if [[ -n "${2}" ]] && [[ "${2}" -ge 1 ]]; then
        num_vcpus="${2}"
      else
         log ERROR "Expected number of CPU >=1 after option -v|--vcpu_count"
        exit 1
      fi
      shift 2
      ;;
    "-d"|"--disk-image")
      disk_image="${2}"
      shift 2
      ;;
    *)
       log ERROR "Invalid argument '${1}'"
      exit 1
  esac
done

log INFO "Creating the VM specs..."

# Create the VM spec.
create_vm_spec

log INFO "...done"

args=(--vmspecfile="vmspec.pb.txt")
# Other args.
args+=(--uid=root)
args+=(--port=8009)
args+=(--alsologtostderr)
args+=(--start_initial_vm)

if [[ "${sev}" == true ]]; then
  args+=(--enable_memory_encryption)
fi

if [[ "${inject_ovmf}" == "true" ]]; then
  args+=(--bios_rom="$(pwd)/ovmf_x64_csm_debug.fd")
fi

instance_name="test_$(date +%s)"

log INFO "Running command:"
echo """
container.py run --overwrite --ram="${container_ram}" ${instance_name} --
  ./test_virtual_machine_monitor --sev_device=/mnt/devtmpfs/sev ${args[@]}
"""

chmod a+rw /mnt/devtmpfs/sev
chmod a+rw /dev/kvm

# Run VMM within a container
container.py run --overwrite --ram="${container_ram}" ${instance_name} -- \
 ./test_virtual_machine_monitor --sev_device=/mnt/devtmpfs/sev ${args[@]}
