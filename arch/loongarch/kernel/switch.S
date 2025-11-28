/* SPDX-License-Identifier: GPL-2.0 */
/*
 * Copyright (C) 2020-2022 Loongson Technology Corporation Limited
 */
#include <asm/asm.h>
#include <asm/asmmacro.h>
#include <asm/asm-offsets.h>
#include <asm/loongarch.h>
#include <asm/regdef.h>
#include <asm/stackframe.h>
#include <asm/thread_info.h>

/*
 * task_struct *__switch_to(task_struct *prev, task_struct *next,
 *			    struct thread_info *next_ti, void *sched_ra, void *sched_cfa)
 */


//下面这句代码在 asmmacro.h 里面有，放在这里呢，是作为提示之用。
//#define TASK_STRUCT_OFFSET THREAD_REG01

	.align	5
SYM_FUNC_START(__switch_to)
#ifdef CONFIG_32BIT
//	la		t1, __1
//	ld.w		t1, t1, 0
//	我希望上面两句，能以一个伪指令如下来实现
//	ld.w		t1, 88f
//	汇编器选择适当的机器指令来实现
//	当88f数小于 2^12时
//	ori	t1, zero, 1234
//	addi	t1, 
//	低位有很多零，并大于2^12时
//	lui	t1, ....
//	确实一个指令放不下立即数时，再加载 88: 处的数
//	ld.w	t1, PC, 88f - .  #汇编器帮忙算偏移，而不是程序员手工数距离

	la		t3, __1
	ld.w		t3, t3, 0
	add.w		a0, a0, t3
// 按照正常的C函数，a0是可以修改后返回，而不会影响调用者的，但这里却崩了。
// 为减少寻址，这里找了一个未曾用到的 垃圾桶寄存器 t3 来让 [a0+t3] 得到 -->thread_sturct

//	PTR_ADDI	a0, a0, TASK_STRUCT_OFFSET
#endif
	csrrd		t1, LOONGARCH_CSR_PRMD
	LONG_STPTR	t1, a0, (THREAD_CSRPRMD - TASK_STRUCT_OFFSET)

	cpu_save_nonscratch a0
	LONG_STPTR	ra, a0, (THREAD_REG01 - TASK_STRUCT_OFFSET)
	LONG_STPTR	a3, a0, (THREAD_SCHED_RA - TASK_STRUCT_OFFSET)
	LONG_STPTR	a4, a0, (THREAD_SCHED_CFA - TASK_STRUCT_OFFSET)

#if defined(CONFIG_STACKPROTECTOR) && !defined(CONFIG_SMP)
	la		t7, __stack_chk_guard
	LONG_L		t8, a1, TASK_STACK_CANARY
	LONG_S		t8, t7, 0
#endif

#ifdef CONFIG_32BIT
//	PTR_ADDI	a1, a1, TASK_STRUCT_OFFSET
	add.w		a1, a1, t3
#endif
	move		tp, a2
	cpu_restore_nonscratch a1

	li.w		t0, _THREAD_SIZE
	PTR_ADD		t0, t0, tp
	set_saved_sp	t0, t1, t2

	LONG_LDPTR	t1, a1, (THREAD_CSRPRMD - TASK_STRUCT_OFFSET)
	csrwr		t1, LOONGARCH_CSR_PRMD

#ifdef CONFIG_32BIT
//	PTR_ADDI	a0, a0, -TASK_STRUCT_OFFSET
//	没有必要吧，a0 难道不可以随便改吗。
//	按 C 语言常识，修改 a0 是不会影响调用函数的
//	mmm... 崩了，不好意思，这东西不是函数
//	定晶一看，确实是函数，算了吧，这个可能是频繁调用代码，接受他（调用者）不规范吧。

	sub.w		a0, a0, t3
#endif
	jr		ra
88:
__1:	.word	THREAD_REG01
__2:	.word	TASK_STRUCT_OFFSET

SYM_FUNC_END(__switch_to)
