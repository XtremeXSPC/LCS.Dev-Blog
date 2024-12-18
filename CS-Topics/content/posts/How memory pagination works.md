---
author: LCS.Dev
date: "2024-12-19T00:36:58.464578"
title: "How Memory Pagination Works"
description: A brief introduction to virtual memory abstraction.
draft: false
showToc: true
TocOpen: true
UseHugoToc: true
hidemeta: false
comments: false
disableHLJS: false
disableShare: false
hideSummary: false
searchHidden: true
ShowReadingTime: true
ShowBreadCrumbs: true
ShowPostNavLinks: true
ShowWordCount: true
ShowRssButtonInSectionTermList: true
tags:
- Operating-Systems
- Virtual-Memory
- Coding
categories:
- Operating Systems
cover:
  image:
  alt:
  caption:
  relative: false
  hidden: true
editPost:
  URL: https://github.com/XtremeXSPC/LCS.Dev-Blog/tree/hostinger/
  Text: Suggest Changes
  appendFilePath: true
---

![Image Description](/images/virtual_memory_translation.png)

## Memory Abstraction: Paging and Its Role in Modern Systems

### What is Paging?

Paging is a memory management scheme that eliminates the need for contiguous memory allocation, enabling the operating system (OS) to manage physical memory more flexibly. In this abstraction, the logical address space (used by a process) is divided into fixed-size units called *pages*, while the physical memory is divided into fixed-size blocks known as *frames*.

A page of the logical address space can be mapped to any frame in the physical memory, thereby avoiding the issues of memory fragmentation and enabling efficient memory utilization. Paging is transparent to the user and application software, meaning the operating system handles all underlying complexities.

---

### Why is Paging Used?

The primary motivations for implementing paging in modern operating systems are:

1. **Elimination of External Fragmentation**
   - Paging divides both physical and logical memory into fixed-size chunks. Because of this, any free frame can accommodate a page of the same size, removing the possibility of *external fragmentation*, where free memory exists but is not usable because of non-contiguous allocation.

2. **Simplification of Memory Allocation**
   - Since pages and frames are of fixed size, managing and allocating memory becomes a simpler task for the OS. There is no need to search for a contiguous block of memory large enough for a process.

3. **Efficient Use of Physical Memory**
   - Paging enables the operating system to load only the required pages of a program into memory, optimizing the use of available physical memory. For example, demand paging allows pages to be loaded only when they are accessed, which reduces memory overhead.

4. **Support for Virtual Memory**
   - Paging is a key technique for implementing virtual memory. Virtual memory allows programs to use more memory than what is physically available by swapping pages in and out of the disk.

5. **Process Isolation**
   - The mapping of logical addresses to physical addresses ensures that processes cannot interfere with each other's memory. This provides robust security and isolation.

---

### How Does Paging Work?

Paging involves two main components:

1. **Logical Addresses and Physical Addresses**
   - The logical address space is divided into pages of size 2^n (e.g., 4 KB), while the physical memory is divided into frames of the same size. When a program generates a logical address, it is split into two parts:
     - *Page Number*: Indicates which page of the logical address space.
     - *Offset*: Specifies the position within the page.

   The operating system maintains a *page table* for each process. The page table maps the page numbers of the logical address space to the corresponding frame numbers in the physical memory.

2. **Translation via Page Table**
   - When the CPU accesses a logical address, the page number is looked up in the page table to retrieve the corresponding frame number. The physical address is then constructed by combining the frame number with the page offset.

   **Formula for Address Translation:**
   - Physical Address = Frame Number \* Page Size + Offset

   Example:
   - Logical Address = Page Number: 3, Offset: 200
   - Page Table Entry: Page 3 \u2192 Frame 5
   - Physical Address = (5 * Page Size) + 200

---

### Paging vs. Segmentation

While paging and segmentation are both memory management techniques, they differ fundamentally in their approach and purpose.

| Feature              | Paging                                | Segmentation                          |
|----------------------|---------------------------------------|---------------------------------------|
| **Division of Memory** | Divides memory into fixed-size pages  | Divides memory into variable-sized segments |
| **Fragmentation**    | Eliminates external fragmentation but causes internal fragmentation | Eliminates internal fragmentation but causes external fragmentation |
| **Size of Units**    | Pages are fixed in size              | Segments are variable in size         |
| **Logical Address**  | Consists of Page Number and Offset   | Consists of Segment Number and Offset |
| **Purpose**          | Focuses on efficient memory allocation | Reflects program structure (e.g., code, data, stack) |
| **Transparency**     | Transparent to users and applications| Visible to programmers for design     |

- **Internal Fragmentation** occurs in paging because a process may not fully use all the space within a page.
- **External Fragmentation** occurs in segmentation because memory holes may exist between variable-sized segments.

---

### Combining Paging and Segmentation

In modern systems, paging and segmentation are often used together to leverage the benefits of both techniques. This combined approach is known as *segmented paging* or *paged segmentation*.

In this scheme:
- The logical address space is divided into segments, each of which is further divided into pages.
- Each segment has its own page table, which maps the pages of that segment to physical frames.
- The logical address consists of three components:
  1. Segment Number
  2. Page Number (within the segment)
  3. Offset (within the page)

**How it works:**
1. The segment number identifies the segment table.
2. The page number identifies the corresponding page table within the segment.
3. The page table maps the page to a physical frame, and the offset determines the exact position within the frame.

This hybrid approach combines the flexibility of segmentation with the simplicity and efficiency of paging, making it suitable for large and complex applications.

---

### Conclusion

Paging is a foundational technique in modern operating systems, enabling efficient memory allocation, process isolation, and virtual memory implementation. Its fixed-size division of memory eliminates external fragmentation but introduces internal fragmentation. In contrast, segmentation aligns with program structure but can lead to external fragmentation.

By combining paging and segmentation, operating systems achieve the best of both worlds: the flexibility of segmentation and the efficient memory management of paging. This synergy ensures that systems can handle the demands of modern applications while optimizing resource utilization.


---


