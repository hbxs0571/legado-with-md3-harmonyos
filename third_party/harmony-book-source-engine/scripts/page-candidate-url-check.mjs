// 页码候选写法 `<第一页,第二页,...>` 的回归：第 N 页取第 N 个候选，超出后沿用最后一个。

import { PageCandidateUrl } from '../sourceengine/src/main/ets/core/rule/PageCandidateUrl.ts';

let assertions = 0;

function equal(actual, expected, message) {
  assertions++;
  if (actual !== expected) {
    throw new Error(`${message}\n  expected: ${expected}\n  actual:   ${actual}`);
  }
}

const twoWay = '/yanqing/<,index_{{page}}.html>';
equal(PageCandidateUrl.apply(twoWay, 1), '/yanqing/', '第 1 页取空候选');
equal(PageCandidateUrl.apply(twoWay, 2), '/yanqing/index_{{page}}.html', '第 2 页取第二个候选，模板留给后续求值');
equal(PageCandidateUrl.apply(twoWay, 9), '/yanqing/index_{{page}}.html', '超出候选数沿用最后一个');

// 三个及以上候选，候选里不需要出现 {{page}}。
const listed = 'https://example.com/top/<index,index_2,index_3>.html';
equal(PageCandidateUrl.apply(listed, 1), 'https://example.com/top/index.html', '多候选第 1 页');
equal(PageCandidateUrl.apply(listed, 2), 'https://example.com/top/index_2.html', '多候选第 2 页');
equal(PageCandidateUrl.apply(listed, 3), 'https://example.com/top/index_3.html', '多候选第 3 页');
equal(PageCandidateUrl.apply(listed, 4), 'https://example.com/top/index_3.html', '多候选超出后取最后一个');

equal(PageCandidateUrl.apply('/s?<p=1, p={{page}} >&q=a', 2), '/s?p={{page}}&q=a', '候选两端空白被去掉');
equal(PageCandidateUrl.apply('/a/<,x>/b/<1,2>', 2), '/a/x/b/2', '同一地址里的多组候选分别处理');
equal(PageCandidateUrl.apply('/a/<,p{{(page-1)*20}}>', 1), '/a/', '第 1 页丢弃带表达式的候选');
equal(PageCandidateUrl.apply('/a/<,p{{Math.max(page,2)}}>', 2), '/a/p{{Math.max(page,2)}}',
  '模板表达式里的括号和逗号不影响候选');
equal(PageCandidateUrl.apply('/a/<,p{{(page-1)*20}}>', 3), '/a/p{{(page-1)*20}}', '带表达式的候选保留模板');
equal(PageCandidateUrl.apply('/a/<f(1),g(2)>', 2), '/a/<f(1),g(2)>', '模板之外含括号的分组不处理');
equal(PageCandidateUrl.apply('/a/<x,{{[page,1].length}}>', 2), '/a/{{[page,1].length}}',
  '模板内的逗号不拆分候选');

// 页码异常时按第 1 页。
equal(PageCandidateUrl.apply(twoWay, 0), '/yanqing/', '页码 0 按第 1 页');
equal(PageCandidateUrl.apply(twoWay, Number.NaN), '/yanqing/', '非数字页码按第 1 页');
equal(PageCandidateUrl.apply(twoWay, 2.9), '/yanqing/index_{{page}}.html', '小数页码向下取整');

// 不是页码候选的内容保持原样。
for (const untouched of [
  '/search?q={{key}}&page={{page}}',
  '<js>java.ajax(url)</js>',
  '/a?b=<c>',
  '/s,{"body":"<a href=\\"x,y\\">1</a>"}',
  '/a?b=<{{[1,2].length}}>',
  '',
]) {
  equal(PageCandidateUrl.apply(untouched, 2), untouched, `不应改写：${untouched}`);
}

// 仍是脚本源码时只改写提到页码模板的分组。
equal(PageCandidateUrl.apply('@js: x<y, y>z; u + "/<,index_{{page}}.html>"', 2, true),
  '@js: x<y, y>z; u + "/index_{{page}}.html"', '脚本源码里只处理带页码模板的分组');
for (const script of ["@js: f('<a,b>')", '@js: (a<b, c>d) ? 1 : 2']) {
  equal(PageCandidateUrl.apply(script, 2, true), script, `脚本源码不应改写：${script}`);
}
equal(PageCandidateUrl.apply('/top/<index,index_2>.html', 2, true), '/top/<index,index_2>.html',
  '要求页码模板时，不含模板的分组保持原样');

console.log(`page-candidate-url-check: ${assertions} assertions passed`);
